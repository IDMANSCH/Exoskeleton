package com.example.leg.identity;

import com.example.leg.identity.AuthModels.AuthOutput;
import com.example.leg.identity.AuthModels.LoginRequest;
import com.example.leg.identity.AuthModels.LogoutRequest;
import com.example.leg.identity.AuthModels.MeOutput;
import com.example.leg.identity.AuthModels.RefreshRequest;
import com.example.leg.identity.AuthModels.RegisterRequest;
import com.example.leg.shared.ApiResponse;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    ApiResponse<AuthOutput> register(@Valid @RequestBody RegisterRequest request) {
        return ApiResponse.of(authService.register(request));
    }

    @PostMapping("/auth/login")
    ApiResponse<AuthOutput> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.of(authService.login(request));
    }

    @PostMapping("/auth/refresh")
    ApiResponse<AuthOutput> refresh(@Valid @RequestBody RefreshRequest request) {
        return ApiResponse.of(authService.refresh(request.refreshToken(), request.deviceLabel()));
    }

    @PostMapping("/auth/logout")
    ApiResponse<Map<String, Boolean>> logout(@AuthenticationPrincipal AuthenticatedUser principal, @Valid @RequestBody LogoutRequest request) {
        authService.logout(principal.id(), request.refreshToken());
        return ApiResponse.of(Map.of("logged_out", true));
    }

    @GetMapping("/me")
    ApiResponse<MeOutput> me(@AuthenticationPrincipal AuthenticatedUser principal) {
        return ApiResponse.of(authService.me(principal.id()));
    }
}
