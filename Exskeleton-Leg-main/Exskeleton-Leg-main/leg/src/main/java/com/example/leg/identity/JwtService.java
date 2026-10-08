package com.example.leg.identity;

import com.example.leg.shared.ApiException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class JwtService {
    private final ObjectMapper objectMapper;
    private final byte[] secret;
    private final String issuer;
    private final String audience;
    private final long accessTokenTtlSeconds;
    private final long refreshTokenTtlSeconds;

    public JwtService(
            ObjectMapper objectMapper,
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.issuer}") String issuer,
            @Value("${app.jwt.audience}") String audience,
            @Value("${app.jwt.access-token-ttl-seconds}") long accessTokenTtlSeconds,
            @Value("${app.jwt.refresh-token-ttl-seconds}") long refreshTokenTtlSeconds) {
        if (secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("JWT secret must contain at least 32 bytes");
        }
        this.objectMapper = objectMapper;
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        this.issuer = issuer;
        this.audience = audience;
        this.accessTokenTtlSeconds = accessTokenTtlSeconds;
        this.refreshTokenTtlSeconds = refreshTokenTtlSeconds;
    }

    String issueAccessToken(UserEntity user) {
        var now = Instant.now().getEpochSecond();
        var header = Map.of("alg", "HS256", "typ", "JWT");
        var payload = new LinkedHashMap<String, Object>();
        payload.put("sub", user.getId().toString());
        payload.put("iss", issuer);
        payload.put("aud", audience);
        payload.put("exp", now + accessTokenTtlSeconds);
        payload.put("iat", now);
        payload.put("jti", UUID.randomUUID().toString());
        payload.put("roles", user.getRoles().stream().sorted().toList());
        return encode(header) + "." + encode(payload) + "." + sign(encode(header) + "." + encode(payload));
    }

    UUID validateAccessToken(String token) {
        try {
            var parts = token.split("\\.");
            if (parts.length != 3 || !constantTimeEquals(sign(parts[0] + "." + parts[1]), parts[2])) {
                throw invalidToken();
            }
            var payload = objectMapper.readValue(Base64.getUrlDecoder().decode(parts[1]), new TypeReference<Map<String, Object>>() {});
            if (!issuer.equals(payload.get("iss")) || !audience.equals(payload.get("aud"))) {
                throw invalidToken();
            }
            var exp = ((Number) payload.get("exp")).longValue();
            if (exp <= Instant.now().getEpochSecond()) {
                throw invalidToken();
            }
            return UUID.fromString((String) payload.get("sub"));
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw invalidToken();
        }
    }

    long accessTokenTtlSeconds() {
        return accessTokenTtlSeconds;
    }

    long refreshTokenTtlSeconds() {
        return refreshTokenTtlSeconds;
    }

    private String encode(Object value) {
        try {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(objectMapper.writeValueAsBytes(value));
        } catch (Exception exception) {
            throw new IllegalStateException("Could not encode JWT", exception);
        }
    }

    private String sign(String value) {
        try {
            var mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Could not sign JWT", exception);
        }
    }

    private boolean constantTimeEquals(String expected, String actual) {
        return MessageDigestSupport.equals(expected.getBytes(StandardCharsets.UTF_8), actual.getBytes(StandardCharsets.UTF_8));
    }

    private ApiException invalidToken() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.");
    }
}
