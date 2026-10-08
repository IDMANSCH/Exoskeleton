package com.example.leg.patients;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
class PatientDataServiceTests {
    @Autowired JdbcTemplate jdbc;
    @Autowired PatientDataService patientData;

    @Test
    void createsAndReadsPatientDataFromDatabase() {
        var id = UUID.randomUUID();
        jdbc.update("insert into users (id,email_normalized,password_hash,display_name,timezone,accepted_terms_version) values (?,?,?,?,?,?)",
                id, id + "@example.com", "hash", "Test Patient", "Asia/Bangkok", "v1");

        var home = patientData.home(id, "Test Patient", "Asia/Bangkok");
        assertThat(home).containsKeys("patient", "device", "next_plan_item", "today_metrics", "open_alerts");
        assertThat(patientData.plans(id, "today")).hasSize(8);
        assertThat(patientData.exercises()).hasSize(8);
        assertThat(patientData.devices(id)).hasSize(1);
        assertThat(patientData.progress(id, "day"))
                .containsKeys("period", "daily", "by_exercise", "insight", "total_repetitions");
    }
}
