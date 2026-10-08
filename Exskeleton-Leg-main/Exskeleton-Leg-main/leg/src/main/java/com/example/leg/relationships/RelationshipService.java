package com.example.leg.relationships;

import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.HashMap;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RelationshipService {
    private final JdbcTemplate jdbc;
    private final com.example.leg.notifications.NotificationService notifications;

    public RelationshipService(JdbcTemplate jdbc, com.example.leg.notifications.NotificationService notifications) {
        this.jdbc = jdbc;
        this.notifications = notifications;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> list(UUID userId) {
        return jdbc.queryForList("""
                select l.id, l.patient_id, l.caregiver_id, l.status, l.requested_by,
                       l.created_at, l.updated_at,
                       p.display_name patient_name, p.email_normalized patient_email,
                       c.display_name caregiver_name, c.email_normalized caregiver_email
                from patient_caregiver_links l
                join users p on p.id = l.patient_id
                join users c on c.id = l.caregiver_id
                where l.patient_id = ? or l.caregiver_id = ?
                order by l.updated_at desc""", userId, userId);
    }

    @Transactional
    public Map<String, Object> invite(UUID requesterId, String email) {
        var requester = jdbc.queryForMap("select id, display_name, email_normalized from users where id=? and status='active'", requesterId);
        var senderName = requester.get("display_name").toString();
        var senderEmail = requester.get("email_normalized").toString();
        var target = jdbc.queryForMap("select id, display_name, email_normalized from users where email_normalized=? and status='active'", email.trim().toLowerCase());
        var targetId = (UUID) target.get("id");
        if (requesterId.equals(targetId)) throw invalid("Không thể liên kết tài khoản với chính mình.");
        var requesterPatient = hasRole(requesterId, "patient");
        var requesterCaregiver = hasRole(requesterId, "caregiver");
        UUID patientId;
        UUID caregiverId;
        if (requesterPatient && hasRole(targetId, "caregiver")) {
            patientId = requesterId; caregiverId = targetId;
        } else if (requesterCaregiver && hasRole(targetId, "patient")) {
            patientId = targetId; caregiverId = requesterId;
        } else {
            throw invalid("Chỉ có thể liên kết người tập với người giám sát.");
        }
        var existing = jdbc.queryForList("select id, status from patient_caregiver_links where patient_id=? and caregiver_id=?", patientId, caregiverId);
        if (!existing.isEmpty()) {
            var status = existing.get(0).get("status").toString();
            if ("active".equals(status)) throw new ApiException(HttpStatus.CONFLICT, "relationship.already_active", "Hai tài khoản đã được liên kết.");
            jdbc.update("update patient_caregiver_links set status='pending', requested_by=?, updated_at=? where patient_id=? and caregiver_id=?", requesterId, Timestamp.from(Instant.now()), patientId, caregiverId);
            notifications.notifyUser(targetId, "Lời mời theo dõi mới",
                    senderName + " (" + senderEmail + ") muốn liên kết với bạn trong Exoskeleton Leg.",
                    inviteData(existing.get(0).get("id").toString(), requesterId, senderName, senderEmail));
            return get((UUID) existing.get(0).get("id"));
        }
        var id = UUID.randomUUID();
        jdbc.update("insert into patient_caregiver_links (id, patient_id, caregiver_id, status, requested_by) values (?, ?, ?, 'pending', ?)", id, patientId, caregiverId, requesterId);
        notifications.notifyUser(targetId, "Lời mời theo dõi mới",
                senderName + " (" + senderEmail + ") muốn liên kết với bạn trong Exoskeleton Leg.",
                inviteData(id.toString(), requesterId, senderName, senderEmail));
        return get(id);
    }

    @Transactional
    public Map<String, Object> changeStatus(UUID requesterId, UUID linkId, String status) {
        var link = jdbc.queryForMap("select * from patient_caregiver_links where id=?", linkId);
        var patientId = (UUID) link.get("patient_id");
        var caregiverId = (UUID) link.get("caregiver_id");
        if (!requesterId.equals(patientId) && !requesterId.equals(caregiverId)) throw denied();
        if ("active".equals(status) && !requesterId.equals(caregiverId) && !requesterId.equals(patientId)) throw denied();
        if (!List.of("active", "rejected", "revoked").contains(status)) throw invalid("Trạng thái liên kết không hợp lệ.");
        jdbc.update("update patient_caregiver_links set status=?, updated_at=? where id=?", status, Timestamp.from(Instant.now()), linkId);
        if ("active".equals(status)) {
            var accepterName = jdbc.queryForObject("select display_name from users where id=?", String.class, requesterId);
            notifications.notifyUser(
                    requesterId.equals(patientId) ? caregiverId : patientId,
                    "Liên kết đã được chấp nhận",
                    accepterName + " đã chấp nhận yêu cầu theo dõi của bạn.",
                    Map.of("type", "relationship_active", "link_id", linkId.toString(),
                            "actor_id", requesterId.toString(), "actor_name", accepterName));
        }
        return get(linkId);
    }

    @Transactional(readOnly = true)
    public void requireCanView(AuthenticatedUser principal, UUID patientId) {
        if (principal == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        if (principal.roles().stream().anyMatch(r -> r.equals("admin") || r.equals("clinician"))) return;
        if (principal.id().equals(patientId) && hasRole(patientId, "patient")) return;
        if (principal.roles().contains("caregiver") && isActiveCaregiver(principal.id(), patientId)) return;
        throw denied();
    }

    @Transactional(readOnly = true)
    public void requireCanManage(AuthenticatedUser principal, UUID patientId) {
        if (principal == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        if (principal.roles().stream().anyMatch(r -> r.equals("admin") || r.equals("clinician"))) return;
        if (principal.roles().contains("patient") && principal.id().equals(patientId)) return;
        if (principal.roles().contains("caregiver") && isActiveCaregiver(principal.id(), patientId)) return;
        throw denied();
    }

    @Transactional(readOnly = true)
    public boolean isActiveCaregiver(UUID caregiverId, UUID patientId) {
        return jdbc.queryForObject("select count(*) from patient_caregiver_links where caregiver_id=? and patient_id=? and status='active'", Integer.class, caregiverId, patientId) > 0;
    }

    private Map<String, Object> get(UUID id) { return jdbc.queryForMap("select l.*, p.display_name patient_name, p.email_normalized patient_email, c.display_name caregiver_name, c.email_normalized caregiver_email from patient_caregiver_links l join users p on p.id=l.patient_id join users c on c.id=l.caregiver_id where l.id=?", id); }
    private Map<String, String> inviteData(String linkId, UUID senderId, String senderName, String senderEmail) {
        var data = new HashMap<String, String>();
        data.put("type", "relationship_invite");
        data.put("link_id", linkId);
        data.put("sender_id", senderId.toString());
        data.put("sender_name", senderName);
        data.put("sender_email", senderEmail);
        return data;
    }
    private boolean hasRole(UUID id, String role) { return jdbc.queryForObject("select count(*) from user_roles where user_id=? and role=?", Integer.class, id, role) > 0; }
    private ApiException denied() { return new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Bạn không có quyền thực hiện thao tác này."); }
    private ApiException invalid(String message) { return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "relationship.invalid", message); }
}
