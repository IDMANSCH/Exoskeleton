package com.example.leg.health;

import com.example.leg.shared.ApiResponse;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {
    private final JdbcTemplate jdbcTemplate;

    public HealthController(DataSource dataSource) {
        this.jdbcTemplate = new JdbcTemplate(dataSource);
    }

    @GetMapping({"/health", "/health/live"})
    ApiResponse<Map<String, String>> live() {
        return ApiResponse.of(Map.of("status", "ok"));
    }

    @GetMapping("/health/ready")
    ApiResponse<Map<String, String>> ready() {
        jdbcTemplate.queryForObject("select 1", Integer.class);
        return ApiResponse.of(Map.of("status", "ok"));
    }

    @GetMapping("/version")
    ApiResponse<Map<String, Object>> version() {
        return ApiResponse.of(Map.of("api", "v1", "service", "leg-springboot"));
    }
}
