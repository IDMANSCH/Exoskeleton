package com.example.leg.relationships;

import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/me/relationships")
public class RelationshipController {
    private final RelationshipService service;
    public RelationshipController(RelationshipService service) { this.service = service; }

    @GetMapping
    ApiResponse<List<Map<String, Object>>> list(@AuthenticationPrincipal AuthenticatedUser principal) {
        return ApiResponse.of(service.list(principal.id()));
    }

    @PostMapping("/invite")
    ApiResponse<Map<String, Object>> invite(@AuthenticationPrincipal AuthenticatedUser principal, @Valid @RequestBody InviteRequest request) {
        return ApiResponse.of(service.invite(principal.id(), request.email()));
    }

    @PostMapping("/{linkId}/accept")
    ApiResponse<Map<String, Object>> accept(@AuthenticationPrincipal AuthenticatedUser principal, @PathVariable UUID linkId) {
        return ApiResponse.of(service.changeStatus(principal.id(), linkId, "active"));
    }

    @PostMapping("/{linkId}/reject")
    ApiResponse<Map<String, Object>> reject(@AuthenticationPrincipal AuthenticatedUser principal, @PathVariable UUID linkId) {
        return ApiResponse.of(service.changeStatus(principal.id(), linkId, "rejected"));
    }

    @PostMapping("/{linkId}/revoke")
    ApiResponse<Map<String, Object>> revoke(@AuthenticationPrincipal AuthenticatedUser principal, @PathVariable UUID linkId) {
        return ApiResponse.of(service.changeStatus(principal.id(), linkId, "revoked"));
    }

    public record InviteRequest(@NotBlank @Email String email) {}
}
