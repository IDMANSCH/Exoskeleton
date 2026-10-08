package com.example.leg.identity;

import com.example.leg.shared.ApiException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.UUID;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtService jwtService;
    private final ObjectMapper objectMapper;
    private final UserRepository users;

    public JwtAuthenticationFilter(JwtService jwtService, ObjectMapper objectMapper, UserRepository users) {
        this.jwtService = jwtService;
        this.objectMapper = objectMapper;
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        var header = request.getHeader("Authorization");
        try {
            if (header != null
                    && header.startsWith("Bearer ")
                    && SecurityContextHolder.getContext().getAuthentication() == null) {
                var userId = jwtService.validateAccessToken(header.substring("Bearer ".length()));
                var user = users.findWithRolesById(userId)
                        .orElseThrow(() -> new ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED,
                                "auth.invalid_token", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn."));
                var principal = new AuthenticatedUser(userId, user.getRoles().stream().sorted().toList());
                var auth = new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        } catch (ApiException exception) {
            SecurityContextHolder.clearContext();
            writeApiError(response, exception);
            return;
        }
        filterChain.doFilter(request, response);
    }

    private void writeApiError(HttpServletResponse response, ApiException exception) throws IOException {
        var error = new LinkedHashMap<String, Object>();
        error.put("code", exception.code());
        error.put("message", exception.getMessage());
        error.put("details", exception.details());
        error.put("request_id", UUID.randomUUID());

        response.setStatus(exception.status().value());
        response.setContentType("application/json");
        objectMapper.writeValue(response.getWriter(), java.util.Map.of("error", error));
    }
}
