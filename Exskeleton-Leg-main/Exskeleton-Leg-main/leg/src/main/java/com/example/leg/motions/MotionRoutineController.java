package com.example.leg.motions;

import com.example.leg.identity.AuthService;
import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import com.example.leg.shared.ApiResponse;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
public class MotionRoutineController {
    private final AuthService auth;
    private final MotionRoutineService routines;
    private final com.example.leg.relationships.RelationshipService relationships;

    public MotionRoutineController(AuthService auth, MotionRoutineService routines,
            com.example.leg.relationships.RelationshipService relationships) { this.auth = auth; this.routines = routines; this.relationships = relationships; }

    @GetMapping("/motion-library")
    public ApiResponse<List<Map<String, Object>>> library(@AuthenticationPrincipal AuthenticatedUser principal) { requireAuth(principal); return ApiResponse.of(routines.library()); }

    @GetMapping("/patients/{patientId}/motion-routines")
    public ApiResponse<List<Map<String, Object>>> list(@PathVariable UUID patientId, @AuthenticationPrincipal AuthenticatedUser principal) { relationships.requireCanView(principal, patientId); return ApiResponse.of(routines.list(patientId)); }

    @PostMapping("/patients/{patientId}/motion-routines")
    public ApiResponse<Map<String, Object>> create(@PathVariable UUID patientId, @RequestBody MotionRoutineService.RoutineRequest request, @AuthenticationPrincipal AuthenticatedUser principal) { relationships.requireCanManage(principal, patientId); return ApiResponse.of(routines.create(patientId, request)); }

    @GetMapping("/patients/{patientId}/motion-routines/{routineId}")
    public ApiResponse<Map<String, Object>> get(@PathVariable UUID patientId, @PathVariable UUID routineId, @AuthenticationPrincipal AuthenticatedUser principal) { relationships.requireCanView(principal, patientId); return ApiResponse.of(routines.get(patientId, routineId)); }

    @PostMapping("/patients/{patientId}/motion-routines/{routineId}/dispatch")
    public ApiResponse<Map<String, Object>> dispatch(@PathVariable UUID patientId, @PathVariable UUID routineId, @AuthenticationPrincipal AuthenticatedUser principal) { relationships.requireCanManage(principal, patientId); return ApiResponse.of(routines.dispatch(patientId, routineId)); }

    private void requireSelf(UUID patientId, AuthenticatedUser principal) { requireAuth(principal); var user = auth.requireUser(principal.id()); if (!user.getId().equals(patientId) || !principal.roles().contains("patient")) throw new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Bạn không có quyền truy cập."); }
    private void requireAuth(AuthenticatedUser principal) { if (principal == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ."); }
}
