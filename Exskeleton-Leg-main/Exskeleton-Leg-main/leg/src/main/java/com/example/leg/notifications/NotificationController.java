package com.example.leg.notifications;

import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.patients.PatientDataService;
import com.example.leg.shared.ApiResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import com.example.leg.shared.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class NotificationController {
    private static final Logger log = LoggerFactory.getLogger(NotificationController.class);

    private final FirebaseMessaging firebaseMessaging;
    private final PatientDataService patientData;
    private final NotificationService notifications;

    public NotificationController(ObjectProvider<FirebaseMessaging> firebaseMessaging, PatientDataService patientData,
            NotificationService notifications) {
        this.firebaseMessaging = firebaseMessaging.getIfAvailable();
        this.patientData = patientData;
        this.notifications = notifications;
    }

    @PostMapping("/me/fcm-token")
    ApiResponse<Map<String, Boolean>> registerFcmToken(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @Valid @RequestBody FcmTokenRequest request) {
        if (principal == null) {
            throw new com.example.leg.shared.ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        patientData.registerToken(principal.id(), request.token(), request.platform());
        log.info("Registered FCM token for user {} on {}", principal.id(), request.platform());
        return ApiResponse.of(Map.of("registered", firebaseMessaging != null));
    }

    public record FcmTokenRequest(@NotBlank String token, @NotBlank String platform) {
    }

    @PostMapping("/admin/notifications/broadcast")
    ApiResponse<NotificationService.BroadcastResult> broadcast(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @Valid @RequestBody BroadcastRequest request) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        if (!principal.roles().contains("admin")) {
            throw new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Chỉ quản trị viên được gửi thông báo toàn hệ thống.");
        }
        if (!"ALL".equals(request.audience())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "notification.audience_required", "Cần xác nhận audience=ALL.");
        }
        return ApiResponse.of(notifications.broadcast(
                principal.id(), request.title().trim(), request.body().trim(), request.dryRun()));
    }

    /**
     * Development-only FCM smoke test. This route intentionally does not use
     * JWT so it can be called from curl/Postman while diagnosing a newly
     * deployed mobile build. Keep it disabled at the edge in production.
     */
    @PostMapping("/test/notifications/broadcast")
    ApiResponse<NotificationService.BroadcastResult> testBroadcast(
            @RequestBody(required = false) TestBroadcastRequest request) {
        var input = request == null ? new TestBroadcastRequest(null, null) : request;
        var title = input.title() == null || input.title().isBlank()
                ? "Kiểm tra thông báo ExoLeg" : input.title().trim();
        var body = input.body() == null || input.body().isBlank()
                ? "Đây là thông báo kiểm thử FCM. Nếu bạn nhìn thấy tin này, điện thoại đã nhận được thông báo."
                : input.body().trim();
        log.warn("Unauthenticated FCM test broadcast requested: title='{}'", title);
        return ApiResponse.of(notifications.broadcast(null, title, body, false));
    }

    public record BroadcastRequest(
            @NotBlank @Size(max = 120) String title,
            @NotBlank @Size(max = 1000) String body,
            @NotBlank String audience,
            boolean dryRun) {}

    public record TestBroadcastRequest(
            @Size(max = 120) String title,
            @Size(max = 1000) String body) {}

    @GetMapping("/me/notifications")
    ApiResponse<java.util.List<java.util.Map<String, Object>>> notifications(
            @AuthenticationPrincipal AuthenticatedUser principal) {
        if (principal == null) {
            throw new com.example.leg.shared.ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        return ApiResponse.of(notifications.forViewer(principal.id()));
    }

    @PostMapping("/patients/{patientId}/alerts/fall")
    ApiResponse<Map<String, Object>> reportFall(
            @org.springframework.web.bind.annotation.PathVariable UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal,
            @RequestBody(required = false) FallRequest request) {
        if (principal == null) {
            throw new com.example.leg.shared.ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        if (!principal.id().equals(patientId) || !principal.roles().contains("patient")) {
            throw new com.example.leg.shared.ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Chỉ người tập mới có thể báo ngã cho tài khoản của mình.");
        }
        var fallRequest = request == null ? new FallRequest("", null, null, null) : request;
        var message = fallRequest.message();
        if ((message == null || message.isBlank()) && fallRequest.fall_probability() != null) {
            message = "Hệ thống phát hiện người tập có thể đã bị ngã (độ tin cậy "
                    + Math.round(fallRequest.fall_probability() * 100) + "%).";
        }
        return ApiResponse.of(notifications.publishFallAlert(patientId, message, fallRequest.alert_id()));
    }

    public record FallRequest(String message, String alert_id, String device_id, Double fall_probability) {}
}
