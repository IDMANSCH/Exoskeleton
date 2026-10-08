package com.example.leg.notifications;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.FirebaseApp;
import com.google.auth.oauth2.GoogleCredentials;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.HashMap;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.fasterxml.jackson.databind.JsonNode;

/** Persists patient alerts and fans them out to active caregiver devices. */
@Service
public class NotificationService {
    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);
    private final JdbcTemplate jdbc;
    private final FirebaseMessaging firebase;
    private final FcmHttpSender httpFallback;
    private final ObjectMapper objectMapper;

    public NotificationService(JdbcTemplate jdbc, ObjectProvider<FirebaseMessaging> firebase,
            ObjectProvider<FirebaseApp> firebaseApp,
            ObjectProvider<GoogleCredentials> firebaseCredentials,
            ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.firebase = firebase.getIfAvailable();
        this.objectMapper = objectMapper;
        var app = firebaseApp.getIfAvailable();
        var credentials = firebaseCredentials.getIfAvailable();
        this.httpFallback = app == null || credentials == null ? null : new FcmHttpSender(app, credentials, objectMapper);
    }

    public record BroadcastResult(UUID broadcastId, boolean dryRun, int users,
            int devices, int acceptedByFcm, int failedDevices) {}

    @Transactional
    public BroadcastResult broadcast(UUID adminId, String title, String body, boolean dryRun) {
        var users = jdbc.queryForList("select id from users where status='active'", UUID.class);
        var tokens = jdbc.queryForList("""
                select distinct t.token from fcm_tokens t
                join users u on u.id=t.user_id
                where u.status='active'""", String.class);
        if (dryRun) {
            return new BroadcastResult(null, true, users.size(), tokens.size(), 0, 0);
        }
        var broadcastId = UUID.randomUUID();
        var data = Map.of("type", "broadcast", "broadcast_id", broadcastId.toString());
        for (var userId : users) {
            persistInbox(userId, "broadcast", title, body, data);
        }
        int accepted = 0;
        int failed = 0;
        if (firebase != null) {
            // FCM limits each multicast call to 500 target devices.
            for (int offset = 0; offset < tokens.size(); offset += 500) {
                var result = send(tokens.subList(offset, Math.min(offset + 500, tokens.size())),
                        title, body, data);
                accepted += result.accepted();
                failed += result.failed();
            }
        } else {
            failed = tokens.size();
            log.warn("Firebase Admin is not configured; broadcast {} saved to inbox only", broadcastId);
        }
        log.info("Broadcast {} by admin {}: users={}, devices={}, accepted={}, failed={}",
                broadcastId, adminId, users.size(), tokens.size(), accepted, failed);
        return new BroadcastResult(broadcastId, false, users.size(), tokens.size(), accepted, failed);
    }

    @Transactional
    public Map<String, Object> publishFallAlert(UUID patientId, String message, String sourceEventId) {
        if (sourceEventId != null && !sourceEventId.isBlank()) {
            var existing = jdbc.query(
                    "select id, patient_id, type, severity, occurred_at from patient_alerts where patient_id=? and source_event_id=?",
                    (rs, rowNum) -> Map.<String, Object>of(
                            "id", rs.getObject("id"),
                            "patient_id", rs.getObject("patient_id"),
                            "type", rs.getString("type"),
                            "severity", rs.getString("severity"),
                            "occurred_at", rs.getTimestamp("occurred_at")),
                    patientId, sourceEventId);
            if (!existing.isEmpty()) return existing.get(0);
        }
        var id = UUID.randomUUID();
        var now = Timestamp.from(Instant.now());
        var text = message == null || message.isBlank() ? "Hệ thống phát hiện người tập có thể đã bị ngã." : message.trim();
        jdbc.update("insert into patient_alerts (id, patient_id, severity, title, message, type, occurred_at, source_event_id) values (?, ?, 'critical', ?, ?, 'fall', ?, ?)",
                id, patientId, "Cảnh báo té ngã", text, now, sourceEventId);
        notifyCaregivers(patientId, "Cảnh báo té ngã", text, Map.of("type", "fall", "patient_id", patientId.toString(), "alert_id", id.toString()));
        return Map.of("id", id, "patient_id", patientId, "type", "fall", "severity", "critical", "occurred_at", now);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> forViewer(UUID viewerId) {
        var notifications = jdbc.queryForList("""
                select id, type, title, body, created_at, read_at, data_json
                from user_notifications where recipient_user_id=?
                order by created_at desc limit 100""", viewerId);
        var alerts = jdbc.queryForList("""
                select a.id, a.patient_id, a.severity, a.title, a.message, a.type, a.occurred_at, a.resolved_at,
                       u.display_name patient_name
                from patient_alerts a join users u on u.id=a.patient_id
                where a.patient_id=? or exists (
                  select 1 from patient_caregiver_links l
                  where l.patient_id=a.patient_id and l.caregiver_id=? and l.status='active'
                )
                order by a.occurred_at desc limit 100""", viewerId, viewerId);
        var result = new java.util.ArrayList<Map<String, Object>>();
        notifications.forEach(item -> {
            var output = new java.util.LinkedHashMap<String, Object>();
            output.put("id", item.get("id"));
            output.put("type", item.get("type"));
            output.put("title", item.get("title"));
            output.put("message", item.get("body"));
            output.put("occurred_at", item.get("created_at"));
            output.put("read_at", item.get("read_at"));
            output.put("source", "inbox");
            try {
                JsonNode data = objectMapper.readTree(String.valueOf(item.get("data_json")));
                data.fields().forEachRemaining(entry -> output.put(entry.getKey(), entry.getValue().asText()));
            } catch (Exception ignored) {
                // Older notifications may not have valid optional metadata.
            }
            result.add(output);
        });
        alerts.forEach(item -> result.add(item));
        result.sort((left, right) -> String.valueOf(right.get("occurred_at"))
                .compareTo(String.valueOf(left.get("occurred_at"))));
        return result;
    }

    @Transactional
    public void notifyUser(UUID userId, String title, String body, Map<String, String> data) {
        persistInbox(userId, data.getOrDefault("type", "general"), title, body, data);
        if (firebase == null) {
            log.warn("Firebase Admin is not configured; user notification skipped for {}", userId);
            return;
        }
        var tokens = jdbc.queryForList("select token from fcm_tokens where user_id=?", String.class, userId);
        if (tokens.isEmpty()) {
            log.warn("No FCM token registered for user {}; notification '{}' cannot be delivered", userId, title);
        }
        send(tokens, title, body, data);
    }

    private void notifyCaregivers(UUID patientId, String title, String body, Map<String, String> data) {
        var patientName = jdbc.queryForObject(
                "select display_name from users where id=?",
                String.class,
                patientId);
        var message = "Người tập " + (patientName == null ? "" : patientName + ": ") + body;
        var notificationData = new HashMap<>(data);
        notificationData.put("patient_name", patientName == null ? "Người tập" : patientName);

        // Always persist a caregiver inbox item first. This keeps the alert visible
        // even when FCM is unavailable, the app is closed, or a token is stale.
        var caregiverIds = jdbc.queryForList("""
                select distinct caregiver_id
                from patient_caregiver_links
                where patient_id=? and status='active'""", UUID.class, patientId);
        for (var caregiverId : caregiverIds) {
            persistInbox(caregiverId, "fall", title, message, notificationData);
        }

        if (firebase == null) {
            log.warn("Firebase Admin is not configured; alert persisted without push notification for patient {}", patientId);
            return;
        }
        var tokens = jdbc.queryForList("""
                select distinct t.token from fcm_tokens t
                join patient_caregiver_links l on l.caregiver_id=t.user_id
                where l.patient_id=? and l.status='active'""", String.class, patientId);
        if (tokens.isEmpty()) {
            log.warn("No caregiver FCM token found for patient {}; notification '{}' cannot be delivered", patientId, title);
        }
        send(tokens, title, message, notificationData);
    }

    private record SendResult(int accepted, int failed) {}

    private SendResult send(List<String> tokens, String title, String body, Map<String, String> data) {
        if (tokens.isEmpty()) return new SendResult(0, 0);
        try {
            var notification = Notification.builder().setTitle(title).setBody(body).build();
            var message = MulticastMessage.builder().addAllTokens(tokens).setNotification(notification).putAllData(data).build();
            var result = firebase.sendEachForMulticast(message);
            log.info("FCM SDK send '{}': devices={}, initial_failures={}",
                    title, result.getSuccessCount() + result.getFailureCount(), result.getFailureCount());
            int accepted = result.getSuccessCount();
            int failed = result.getFailureCount();
            for (int i = 0; i < result.getResponses().size(); i++) {
                var response = result.getResponses().get(i);
                if (!response.isSuccessful()) {
                    var exception = response.getException();
                    if (isGzipTransportFailure(exception) && httpFallback != null) {
                        try {
                            httpFallback.send(tokens.get(i), title, body, data);
                            log.info("FCM HTTP v1 fallback delivered notification to token {}", mask(tokens.get(i)));
                            accepted++;
                            failed--;
                            continue;
                        } catch (Exception fallbackError) {
                            log.error("FCM HTTP v1 fallback failed for token {}", mask(tokens.get(i)), fallbackError);
                        }
                    }
                    log.warn("FCM delivery failed for token {}: {}", mask(tokens.get(i)), exception);
                    if (exception != null && exception.getMessagingErrorCode() != null
                            && (exception.getMessagingErrorCode().name().contains("UNREGISTERED")
                            || exception.getMessagingErrorCode().name().contains("INVALID_ARGUMENT"))) {
                        jdbc.update("delete from fcm_tokens where token=?", tokens.get(i));
                    }
                }
            }
            return new SendResult(accepted, failed);
        } catch (Exception exception) {
            log.error("Could not send push notification", exception);
            return new SendResult(0, tokens.size());
        }
    }

    private boolean isGzipTransportFailure(Throwable error) {
        for (var cause = error; cause != null; cause = cause.getCause()) {
            if (cause instanceof java.util.zip.ZipException) return true;
        }
        return false;
    }

    private void persistInbox(UUID userId, String type, String title, String body, Map<String, String> data) {
        try {
            jdbc.update("insert into user_notifications (id, recipient_user_id, type, title, body, data_json) values (?, ?, ?, ?, ?, ?)",
                    UUID.randomUUID(), userId, type, title, body, objectMapper.writeValueAsString(data));
        } catch (JsonProcessingException exception) {
            jdbc.update("insert into user_notifications (id, recipient_user_id, type, title, body) values (?, ?, ?, ?, ?)",
                    UUID.randomUUID(), userId, type, title, body);
        }
    }

    private String mask(String token) {
        return token == null || token.length() < 12 ? "<short-token>" : token.substring(0, 8) + "…" + token.substring(token.length() - 4);
    }
}
