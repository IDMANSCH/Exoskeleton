package com.example.leg.identity;

import com.example.leg.identity.AuthModels.AuthOutput;
import com.example.leg.identity.AuthModels.LoginRequest;
import com.example.leg.identity.AuthModels.MeOutput;
import com.example.leg.identity.AuthModels.PublicUser;
import com.example.leg.identity.AuthModels.RegisterRequest;
import com.example.leg.shared.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private final UserRepository users;
    private final RefreshSessionRepository refreshSessions;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(
            UserRepository users,
            RefreshSessionRepository refreshSessions,
            PasswordEncoder passwordEncoder,
            JwtService jwtService) {
        this.users = users;
        this.refreshSessions = refreshSessions;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public AuthOutput register(RegisterRequest request) {
        var email = normalizeEmail(request.email());
        validatePassword(request.password());
        var displayName = trimmedRequired("display_name", request.displayName(), 2, 100);
        var timezone = trimmedRequired("timezone", request.timezone(), 1, 100);
        var terms = trimmedRequired("accepted_terms_version", request.acceptedTermsVersion(), 1, 50);
        var locale = locale(request.locale());
        if (users.existsByEmailNormalized(email)) {
            throw emailAlreadyExists();
        }

        var user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setEmailNormalized(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setDisplayName(displayName);
        user.setLocale(locale);
        user.setTimezone(timezone);
        user.setAcceptedTermsVersion(terms);
        user.setRoles(new HashSet<>(Set.of(registerRole(request.role()))));
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException exception) {
            throw emailAlreadyExists();
        }
        return createSession(user, request.deviceLabel());
    }

    @Transactional
    public AuthOutput login(LoginRequest request) {
        var email = normalizeEmail(request.email());
        var user = users.findByEmailNormalized(email).orElseThrow(this::invalidCredentials);
        ensureActive(user);
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw invalidCredentials();
        }
        return createSession(user, request.deviceLabel());
    }

    @Transactional
    public AuthOutput refresh(String refreshToken, String deviceLabel) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw invalidRefreshToken();
        }
        var now = Instant.now();
        var current = refreshSessions.findByTokenHash(hashRefreshToken(refreshToken)).orElseThrow(this::invalidRefreshToken);
        if (current.getRevokedAt() != null) {
            refreshSessions.revokeFamily(current.getFamilyId(), now);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "auth.refresh_token_reused", "Phát hiện phiên đăng nhập không an toàn. Vui lòng đăng nhập lại.");
        }
        if (!current.getExpiresAt().isAfter(now)) {
            current.setRevokedAt(now);
            current.setLastUsedAt(now);
            throw invalidRefreshToken();
        }

        var replacementToken = randomToken();
        var replacement = buildRefreshSession(current.getUser(), replacementToken, deviceLabel);
        replacement.setFamilyId(current.getFamilyId());
        replacement.setRotatedFromId(current.getId());
        refreshSessions.save(replacement);
        current.setRevokedAt(now);
        current.setLastUsedAt(now);
        ensureActive(current.getUser());
        return authOutput(current.getUser(), replacementToken);
    }

    @Transactional
    public void logout(UUID userId, String refreshToken) {
        var affected = refreshSessions.revokeActive(userId, hashRefreshToken(refreshToken), Instant.now());
        if (affected == 0) {
            throw invalidRefreshToken();
        }
    }

    @Transactional(readOnly = true)
    public MeOutput me(UUID userId) {
        var user = users.findWithRolesById(userId).orElseThrow(this::invalidAccessToken);
        ensureActive(user);
        return MeOutput.from(user);
    }

    @Transactional(readOnly = true)
    public UserEntity requireUser(UUID userId) {
        var user = users.findWithRolesById(userId).orElseThrow(this::invalidAccessToken);
        ensureActive(user);
        return user;
    }

    private AuthOutput createSession(UserEntity user, String deviceLabel) {
        ensureActive(user);
        var refreshToken = randomToken();
        refreshSessions.save(buildRefreshSession(user, refreshToken, deviceLabel));
        return authOutput(user, refreshToken);
    }

    private AuthOutput authOutput(UserEntity user, String refreshToken) {
        return new AuthOutput(
                jwtService.issueAccessToken(user),
                jwtService.accessTokenTtlSeconds(),
                refreshToken,
                jwtService.refreshTokenTtlSeconds(),
                PublicUser.from(user));
    }

    private RefreshSessionEntity buildRefreshSession(UserEntity user, String refreshToken, String deviceLabel) {
        var id = UUID.randomUUID();
        var session = new RefreshSessionEntity();
        session.setId(id);
        session.setUser(user);
        session.setFamilyId(id);
        session.setTokenHash(hashRefreshToken(refreshToken));
        session.setDeviceLabel(cleanDeviceLabel(deviceLabel));
        session.setExpiresAt(Instant.now().plusSeconds(jwtService.refreshTokenTtlSeconds()));
        return session;
    }

    private String cleanDeviceLabel(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        var trimmed = value.trim();
        return trimmed.length() > 100 ? trimmed.substring(0, 100) : trimmed;
    }

    private String normalizeEmail(String value) {
        var email = value == null ? "" : value.trim().toLowerCase();
        var parts = email.split("@", -1);
        if (email.length() > 254 || parts.length != 2 || parts[0].isBlank() || parts[1].isBlank() || !parts[1].contains(".")) {
            throw validation("email", "Email không hợp lệ.");
        }
        return email;
    }

    private void validatePassword(String value) {
        var length = value == null ? 0 : value.codePointCount(0, value.length());
        if (length < 8 || length > 128) {
            throw validation("password", "Mật khẩu cần từ 8 đến 128 ký tự.");
        }
    }

    private String trimmedRequired(String field, String value, int min, int max) {
        var trimmed = value == null ? "" : value.trim();
        var length = trimmed.codePointCount(0, trimmed.length());
        if (length < min || length > max) {
            throw validation(field, "Giá trị không hợp lệ.");
        }
        return trimmed;
    }

    private String locale(String value) {
        var locale = value == null || value.isBlank() ? "vi" : value.trim();
        if (!locale.equals("vi") && !locale.equals("en")) {
            throw validation("locale", "Ngôn ngữ chỉ hỗ trợ vi hoặc en.");
        }
        return locale;
    }

    private String registerRole(String value) {
        var role = value == null || value.isBlank() ? "patient" : value.trim().toLowerCase();
        if (!role.equals("patient") && !role.equals("caregiver")) {
            throw validation("role", "Chỉ có thể đăng ký vai trò người tập hoặc người giám sát.");
        }
        return role;
    }

    private void ensureActive(UserEntity user) {
        if (!"active".equals(user.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Tài khoản hiện không thể sử dụng.");
        }
    }

    private byte[] hashRefreshToken(String token) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
        } catch (Exception exception) {
            throw new IllegalStateException("Could not hash refresh token", exception);
        }
    }

    private String randomToken() {
        var id = UUID.randomUUID().toString() + UUID.randomUUID();
        return Base64.getUrlEncoder().withoutPadding().encodeToString(HexFormat.of().parseHex(id.replace("-", "")));
    }

    private ApiException validation(String field, String message) {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "validation.invalid_field", message, java.util.Map.of("field", field));
    }

    private ApiException emailAlreadyExists() {
        return new ApiException(HttpStatus.CONFLICT, "identity.email_already_exists", "Email này đã được sử dụng.");
    }

    private ApiException invalidCredentials() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_credentials", "Email hoặc mật khẩu không đúng.");
    }

    private ApiException invalidAccessToken() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.");
    }

    private ApiException invalidRefreshToken() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_refresh_token", "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.");
    }
}
