package com.example.leg.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@Transactional
class NotificationBroadcastTests {
    @Autowired JdbcTemplate jdbc;
    @Autowired NotificationController controller;

    @Test
    void onlyAdminMayBroadcastAndDryRunDoesNotWrite() {
        var admin = createUser("active");
        var patient = createUser("active");
        var locked = createUser("locked");
        jdbc.update("insert into fcm_tokens (id,user_id,token,platform) values (?,?,?,?)",
                UUID.randomUUID(), patient, "test-device-" + UUID.randomUUID(), "android");
        jdbc.update("insert into fcm_tokens (id,user_id,token,platform) values (?,?,?,?)",
                UUID.randomUUID(), locked, "test-device-" + UUID.randomUUID(), "android");
        var request = new NotificationController.BroadcastRequest("Kiểm tra", "Nội dung", "ALL", true);

        assertThrows(ApiException.class, () -> controller.broadcast(
                new AuthenticatedUser(patient, List.of("patient")), request));
        assertThrows(ApiException.class, () -> controller.broadcast(
                new AuthenticatedUser(admin, List.of("admin")),
                new NotificationController.BroadcastRequest("Kiểm tra", "Nội dung", "ONE", true)));

        var before = jdbc.queryForObject("select count(*) from user_notifications", Integer.class);
        var result = controller.broadcast(new AuthenticatedUser(admin, List.of("admin")), request).data();
        assertEquals(true, result.dryRun());
        assertEquals(2, result.users());
        assertEquals(1, result.devices());
        assertEquals(before, jdbc.queryForObject("select count(*) from user_notifications", Integer.class));
    }

    @Test
    void broadcastPersistsInboxForActiveUsers() {
        var admin = createUser("active");
        var patient = createUser("active");
        var locked = createUser("locked");
        var result = controller.broadcast(new AuthenticatedUser(admin, List.of("admin")),
                new NotificationController.BroadcastRequest("Thông báo", "Kiểm tra FCM", "ALL", false)).data();

        assertEquals(false, result.dryRun());
        assertEquals(2, result.users());
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from user_notifications where recipient_user_id=? and type='broadcast'",
                Integer.class, patient));
        assertEquals(0, jdbc.queryForObject(
                "select count(*) from user_notifications where recipient_user_id=? and type='broadcast'",
                Integer.class, locked));
    }

    private UUID createUser(String status) {
        var id = UUID.randomUUID();
        jdbc.update("""
                insert into users (id,email_normalized,password_hash,display_name,status,timezone,accepted_terms_version)
                values (?,?,?,?,?,?,?)""",
                id, id + "@example.com", "hash", "Test", status, "Asia/Bangkok", "v1");
        return id;
    }
}
