package com.example.leg.patients;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.leg.shared.ApiResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class PatientHomeSerializationTests {
    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void serializesPatientHomeReadModelWithIsoTimestamps() throws Exception {
        var patientId = "829a87f9-59de-4f39-8872-762203080026";
        var response = ApiResponse.of(Map.of(
                "patient", Map.of("id", patientId, "display_name", "Nguyen An", "timezone", "Asia/Bangkok"),
                "device", Map.of("last_seen_at", Instant.now()),
                "open_alerts", List.of(Map.of("occurred_at", Instant.now()))));

        var json = objectMapper.writeValueAsString(response);

        assertThat(json).contains("\"last_seen_at\":\"");
        assertThat(json).contains("\"occurred_at\":\"");
        assertThat(json).contains("\"id\":\"" + patientId + "\"");
        assertThat(json).doesNotContain("[2026");
    }
}
