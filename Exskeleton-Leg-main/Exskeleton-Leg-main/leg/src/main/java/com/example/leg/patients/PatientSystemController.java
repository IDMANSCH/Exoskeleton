package com.example.leg.patients;

import com.example.leg.identity.AuthService;
import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import com.example.leg.shared.ApiResponse;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Read models consumed by the current patient mobile shell. */
@RestController
@RequestMapping("/api/v1")
public class PatientSystemController {
    private final AuthService authService;
    private final PatientDataService patientData;
    private final com.example.leg.relationships.RelationshipService relationships;

    public PatientSystemController(AuthService authService, PatientDataService patientData,
            com.example.leg.relationships.RelationshipService relationships) {
        this.authService = authService;
        this.patientData = patientData;
        this.relationships = relationships;
    }

    @GetMapping("/patients/{patientId}")
    public ApiResponse<Map<String, Object>> patient(@PathVariable UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        relationships.requireCanView(principal, patientId);
        var user = authService.requireUser(patientId);
        return ApiResponse.of(Map.of(
                "id", user.getId(), "display_name", user.getDisplayName(), "email", user.getEmailNormalized(),
                "locale", user.getLocale(), "timezone", user.getTimezone(), "version", 1));
    }

    @GetMapping("/patients/{patientId}/plan-items/today")
    public ApiResponse<List<Map<String, Object>>> today(@PathVariable UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        relationships.requireCanView(principal, patientId);
        return ApiResponse.of(patientData.plans(patientId, "today"));

    }

    @GetMapping("/exercises")
    public ApiResponse<List<Map<String, Object>>> exercises(@AuthenticationPrincipal AuthenticatedUser principal) {
        requireAuthenticated(principal);
        return ApiResponse.of(patientData.exercises());
    }

    @GetMapping("/exercises/{exerciseId}")
    public ApiResponse<Map<String, Object>> exercise(@PathVariable UUID exerciseId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireAuthenticated(principal);
        try {
            return ApiResponse.of(patientData.exercise(exerciseId));
        } catch (org.springframework.dao.EmptyResultDataAccessException exception) {
            throw new ApiException(HttpStatus.NOT_FOUND, "exercise.not_found", "Không tìm thấy bài tập.");
        }
    }

    @GetMapping("/patients/{patientId}/plan-items")
    public ApiResponse<List<Map<String, Object>>> allPlans(@PathVariable UUID patientId,
            @RequestParam(defaultValue = "all") String scope,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        relationships.requireCanView(principal, patientId);
        if (!scope.equals("all") && !scope.equals("today")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "validation.invalid_scope", "Scope không hợp lệ.");
        }
        return ApiResponse.of(patientData.plans(patientId, scope));
    }

    @GetMapping("/patients/{patientId}/progress/overview")
    public ApiResponse<Map<String, Object>> progress(@PathVariable UUID patientId,
            @RequestParam(defaultValue = "week") String period,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        relationships.requireCanView(principal, patientId);
        if (!period.equals("day") && !period.equals("week") && !period.equals("month")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "validation.invalid_period", "Period không hợp lệ.");
        }
        return ApiResponse.of(patientData.progress(patientId, period));
    }

    @GetMapping("/patients/{patientId}/alerts")
    public ApiResponse<List<Map<String, Object>>> alerts(@PathVariable UUID patientId,
            @RequestParam(defaultValue = "20") int limit,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        relationships.requireCanView(principal, patientId);
        return ApiResponse.of(patientData.alerts(patientId, Math.max(1, Math.min(limit, 100))));
    }

    @PostMapping("/patients/{patientId}/training-sessions/complete")
    public ApiResponse<Map<String, Object>> completeTrainingSession(
            @PathVariable UUID patientId,
            @RequestBody CompletionRequest request,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        return ApiResponse.of(patientData.completeSession(patientId, request));
    }

    @GetMapping("/devices")
    public ApiResponse<List<Map<String, Object>>> devices(@RequestParam("patient_id") UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        return ApiResponse.of(patientData.devices(patientId));
    }

    @GetMapping("/devices/{deviceId}")
    public ApiResponse<Map<String, Object>> device(@PathVariable UUID deviceId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        if (principal == null) throw denied();
        var devices = patientData.devices(principal.id());
        return devices.stream().filter(device -> deviceId.equals(device.get("id"))).findFirst()
                .map(ApiResponse::of).orElseThrow(this::denied);
    }

    private com.example.leg.identity.UserEntity requireSelf(UUID patientId, AuthenticatedUser principal) {
        if (principal == null) throw denied();
        var user = authService.requireUser(principal.id());
        if (!user.getId().equals(patientId) || !principal.roles().contains("patient")) throw denied();
        return user;
    }

    private void requireAuthenticated(AuthenticatedUser principal) {
        if (principal == null) throw denied();
    }

    private ApiException denied() {
        return new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Bạn không có quyền xem dữ liệu này.");
    }

    public record CompletionRequest(
            UUID sessionId,
            UUID planItemId,
            String exerciseCode,
            int completedRepetitions,
            int activeSeconds,
            double correctnessRatio) {
    }
}
