package com.example.leg.patients;

import com.example.leg.identity.AuthService;
import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import com.example.leg.shared.ApiResponse;
import java.util.List;
import java.util.UUID;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {
    private final AuthService authService;
    private final PatientDataService patientData;
    private final com.example.leg.relationships.RelationshipService relationships;

    public PatientController(AuthService authService, PatientDataService patientData,
            com.example.leg.relationships.RelationshipService relationships) {
        this.authService = authService;
        this.patientData = patientData;
        this.relationships = relationships;
    }

    @GetMapping("/{patientId}/home")
    public ApiResponse<java.util.Map<String, Object>> patientHome(
            @PathVariable UUID patientId, @AuthenticationPrincipal AuthenticatedUser principal) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        relationships.requireCanView(principal, patientId);
        var patient = authService.requireUser(patientId);
        return ApiResponse.of(patientData.home(patient.getId(), patient.getDisplayName(), patient.getTimezone()));
    }

}
