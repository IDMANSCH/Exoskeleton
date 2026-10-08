package com.example.leg.patients;

import java.sql.ResultSet;
import java.time.Instant;
import java.time.LocalDate;
import java.sql.Timestamp;
import java.sql.Date;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Database-backed patient read models and notification registration. */
@Service
public class PatientDataService {
    private static final UUID SIT_TO_STAND = UUID.fromString("20000000-0000-0000-0000-000000000001");
    private static final UUID WALK = UUID.fromString("20000000-0000-0000-0000-000000000009");
    private static final UUID RAISE_LEFT_LEG = UUID.fromString("20000000-0000-0000-0000-000000000010");
    private static final UUID RAISE_RIGHT_LEG = UUID.fromString("20000000-0000-0000-0000-000000000011");
    private static final UUID KICK_LEFT_LEG = UUID.fromString("20000000-0000-0000-0000-000000000012");
    private static final UUID KICK_RIGHT_LEG = UUID.fromString("20000000-0000-0000-0000-000000000013");
    private static final UUID KICK_LEFT_KNEE = UUID.fromString("20000000-0000-0000-0000-000000000014");
    private static final UUID KICK_RIGHT_KNEE = UUID.fromString("20000000-0000-0000-0000-000000000015");
    private final JdbcTemplate jdbc;

    public PatientDataService(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @Transactional
    public void ensurePatient(UUID patientId) {
        if (jdbc.queryForObject("select count(*) from patient_devices where patient_id = ?", Integer.class, patientId) == 0) {
            jdbc.update("insert into patient_devices (id, patient_id, serial_number, model, firmware_version, online, last_seen_at, battery_percent, readiness_state, sensors_state, motors_state, controller_state, estop_state, calibration_status, calibration_expires_at) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    UUID.randomUUID(), patientId, "EXO-" + patientId.toString().substring(0, 8).toUpperCase(), "exo-leg-v1", "1.2.0", true, Timestamp.from(Instant.now()), 78, "ready", "ok", "ok", "ok", "ok", "valid", Date.valueOf(LocalDate.now().plusDays(31)));
        }
        addPlanIfMissing(patientId, WALK, 2, 10, 600);
        addPlanIfMissing(patientId, RAISE_LEFT_LEG, 2, 8, 480);
        addPlanIfMissing(patientId, RAISE_RIGHT_LEG, 2, 8, 480);
        addPlanIfMissing(patientId, SIT_TO_STAND, 2, 8, 600);
        addPlanIfMissing(patientId, KICK_LEFT_LEG, 2, 8, 420);
        addPlanIfMissing(patientId, KICK_RIGHT_LEG, 2, 8, 420);
        addPlanIfMissing(patientId, KICK_LEFT_KNEE, 2, 8, 420);
        addPlanIfMissing(patientId, KICK_RIGHT_KNEE, 2, 8, 420);
    }

    private void addPlanIfMissing(UUID patientId, UUID exerciseId, int sets, int reps, int seconds) {
        var planDate = Date.valueOf(LocalDate.now());
        if (jdbc.queryForObject("select count(*) from patient_plan_items where patient_id = ? and exercise_id = ? and plan_date = ?", Integer.class, patientId, exerciseId, planDate) > 0) {
            return;
        }
        jdbc.update("insert into patient_plan_items (id, patient_id, exercise_id, plan_date, sets, repetitions_per_set, rest_seconds, assistance_level, estimated_duration_seconds) values (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), patientId, exerciseId, planDate, sets, reps, 60, "low", seconds);
    }

    public Map<String, Object> home(UUID patientId, String displayName, String timezone) {
        ensurePatient(patientId);
        var device = jdbc.queryForMap("select * from patient_devices where patient_id = ? order by serial_number limit 1", patientId);
        var plans = jdbc.queryForList("select p.*, e.code exercise_code, e.name exercise_name, e.image_asset from patient_plan_items p join exercises e on e.id=p.exercise_id where p.patient_id=? and p.plan_date=? and e.active=true order by p.id", patientId, Date.valueOf(LocalDate.now()));
        var next = plans.stream().filter(p -> !"completed".equals(p.get("status"))).findFirst().map(this::homePlanOutput).orElse(null);
        var metrics = jdbc.queryForMap("select count(*) planned_count, coalesce(sum(case when status='completed' then 1 else 0 end),0) completed_count from patient_plan_items where patient_id=? and plan_date=?", patientId, Date.valueOf(LocalDate.now()));
        var sessions = jdbc.queryForMap("select coalesce(sum(active_seconds),0) active_seconds, avg(correctness_ratio) correctness_ratio from training_sessions where patient_id=? and started_at >= ?", patientId, Timestamp.from(LocalDate.now().atStartOfDay().toInstant(java.time.ZoneOffset.UTC)));
        var alerts = jdbc.queryForList("select * from patient_alerts where patient_id=? and resolved_at is null order by occurred_at desc", patientId).stream().map(this::alertOutput).toList();
        var output = new LinkedHashMap<String, Object>();
        output.put("patient", Map.of("id", patientId, "display_name", displayName, "timezone", timezone));
        output.put("device", deviceOutput(device));
        output.put("next_plan_item", next);
        output.put("today_metrics", Map.of("planned_count", metrics.get("planned_count"), "completed_count", metrics.get("completed_count"), "active_seconds", sessions.get("active_seconds"), "correctness_ratio", sessions.get("correctness_ratio") == null ? 0 : sessions.get("correctness_ratio")));
        output.put("open_alerts", alerts);
        output.put("recent_session", null);
        return output;
    }

    public List<Map<String, Object>> plans(UUID patientId, String scope) { ensurePatient(patientId); var sql = "all".equals(scope) ? "select p.*, e.id exercise_id, e.code exercise_code, e.name exercise_name, e.category exercise_category, e.name_key, e.description_key, e.instructions_key, e.safety_key, e.difficulty, e.requires_support, e.image_asset from patient_plan_items p join exercises e on e.id=p.exercise_id where p.patient_id=? and e.active=true order by p.plan_date desc, p.id" : "select p.*, e.id exercise_id, e.code exercise_code, e.name exercise_name, e.category exercise_category, e.name_key, e.description_key, e.instructions_key, e.safety_key, e.difficulty, e.requires_support, e.image_asset from patient_plan_items p join exercises e on e.id=p.exercise_id where p.patient_id=? and p.plan_date=? and e.active=true order by p.id"; var args = "all".equals(scope) ? new Object[] {patientId} : new Object[] {patientId, Date.valueOf(LocalDate.now())}; return jdbc.queryForList(sql, args).stream().map(this::planOutput).toList(); }
    public Map<String, Object> progress(UUID patientId, String period) {
        ensurePatient(patientId);
        var days = "day".equals(period) ? 1 : ("month".equals(period) ? 30 : 7);
        var start = LocalDate.now().minusDays(days - 1L);
        var row = jdbc.queryForMap(
                "select count(*) planned_count, coalesce(sum(case when status='completed' then 1 else 0 end),0) completed_count from patient_plan_items where patient_id=? and plan_date >= ? and plan_date <= ?",
                patientId, Date.valueOf(start), Date.valueOf(LocalDate.now()));
        var startTimestamp = Timestamp.from(start.atStartOfDay().toInstant(java.time.ZoneOffset.UTC));
        var sessions = jdbc.queryForMap(
                "select count(*) session_count, coalesce(sum(active_seconds),0) active_seconds, coalesce(sum(completed_repetitions),0) total_repetitions, avg(correctness_ratio) correctness_ratio from training_sessions where patient_id=? and status='completed' and started_at >= ?",
                patientId, startTimestamp);
        var history = jdbc.queryForList(
                "select id, plan_item_id, exercise_code, started_at, completed_at, active_seconds, correctness_ratio, completed_repetitions, status from training_sessions where patient_id=? and started_at >= ? order by started_at desc limit 20",
                patientId, startTimestamp);
        var alertCounts = jdbc.queryForMap(
                "select coalesce(sum(case when severity='warning' then 1 else 0 end),0) warning_count, coalesce(sum(case when severity='critical' then 1 else 0 end),0) critical_count from patient_alerts where patient_id=? and occurred_at >= ?",
                patientId, startTimestamp);
        var completedDays = jdbc.queryForList(
                "select distinct plan_date from patient_plan_items where patient_id=? and status='completed' and plan_date between ? and ? order by plan_date desc",
                Date.class, patientId, Date.valueOf(start), Date.valueOf(LocalDate.now()));
        var streak = 0;
        var day = LocalDate.now();
        for (var completedDay : completedDays) {
            if (!completedDay.toLocalDate().equals(day)) break;
            streak++;
            day = day.minusDays(1);
        }
        var dailyRows = jdbc.queryForList(
                "select cast(started_at as date) activity_date, count(*) session_count, coalesce(sum(active_seconds),0) active_seconds, coalesce(sum(completed_repetitions),0) repetitions from training_sessions where patient_id=? and status='completed' and started_at >= ? group by cast(started_at as date) order by activity_date",
                patientId, startTimestamp);
        var dailyByDate = new LinkedHashMap<LocalDate, Map<String, Object>>();
        for (var daily : dailyRows) {
            var value = daily.get("activity_date");
            var date = value instanceof Date sqlDate ? sqlDate.toLocalDate() : LocalDate.parse(value.toString());
            dailyByDate.put(date, Map.of(
                    "date", date.toString(),
                    "session_count", daily.get("session_count"),
                    "active_seconds", daily.get("active_seconds"),
                    "repetitions", daily.get("repetitions")));
        }
        var daily = new ArrayList<Map<String, Object>>();
        for (var offset = 0; offset < days; offset++) {
            var date = start.plusDays(offset);
            daily.add(dailyByDate.getOrDefault(date, Map.of(
                    "date", date.toString(), "session_count", 0,
                    "active_seconds", 0, "repetitions", 0)));
        }
        var byExercise = jdbc.queryForList(
                "select exercise_code, count(*) session_count, coalesce(sum(completed_repetitions),0) repetitions, coalesce(sum(active_seconds),0) active_seconds from training_sessions where patient_id=? and status='completed' and started_at >= ? group by exercise_code order by repetitions desc, active_seconds desc limit 5",
                patientId, startTimestamp);
        var completed = ((Number) row.get("completed_count")).intValue();
        var planned = ((Number) row.get("planned_count")).intValue();
        var completionRate = planned == 0 ? 0.0 : (double) completed / planned;
        var insight = completed == 0
                ? "Hôm nay là một khởi đầu tốt — hãy hoàn thành phiên đầu tiên của bạn."
                : streak >= 3
                    ? "Bạn đang giữ nhịp rất tốt. Tiếp tục thêm một phiên ngắn để duy trì streak."
                    : "Mỗi phiên đều được ghi nhận. Một phiên ngắn hôm nay cũng tạo khác biệt.";
        var output = new LinkedHashMap<String, Object>();
        output.put("period", period);
        output.put("from", start.toString());
        output.put("to", LocalDate.now().toString());
        output.put("planned_count", planned);
        output.put("completed_count", completed);
        output.put("completion_rate", completionRate);
        output.put("session_count", sessions.get("session_count"));
        output.put("active_seconds", sessions.get("active_seconds"));
        output.put("total_repetitions", sessions.get("total_repetitions"));
        output.put("correctness_ratio", sessions.get("correctness_ratio") == null ? 0 : sessions.get("correctness_ratio"));
        output.put("warning_count", alertCounts.get("warning_count"));
        output.put("critical_count", alertCounts.get("critical_count"));
        output.put("streak_days", streak);
        output.put("insight", insight);
        output.put("daily", daily);
        output.put("by_exercise", byExercise);
        output.put("recent_sessions", history);
        return output;
    }

    @Transactional
    public Map<String, Object> completeSession(UUID patientId,
            PatientSystemController.CompletionRequest request) {
        ensurePatient(patientId);
        if (request.sessionId() == null || request.planItemId() == null
                || request.exerciseCode() == null || request.exerciseCode().isBlank()) {
            throw new IllegalArgumentException("sessionId, planItemId and exerciseCode are required");
        }
        if (request.completedRepetitions() < 0 || request.activeSeconds() < 0
                || request.correctnessRatio() < 0 || request.correctnessRatio() > 1) {
            throw new IllegalArgumentException("invalid completion metrics");
        }
        var plan = jdbc.queryForMap(
                "select id, exercise_id, sets, repetitions_per_set from patient_plan_items where id=? and patient_id=?",
                request.planItemId(), patientId);
        var now = Timestamp.from(Instant.now());
        var updated = jdbc.update("update training_sessions set completed_at=?, active_seconds=?, correctness_ratio=?, completed_repetitions=?, exercise_code=?, status='completed' where id=? and patient_id=?",
                now, request.activeSeconds(), request.correctnessRatio(), request.completedRepetitions(), request.exerciseCode(),
                request.sessionId(), patientId);
        if (updated == 0) {
            jdbc.update("insert into training_sessions (id, patient_id, plan_item_id, started_at, completed_at, active_seconds, correctness_ratio, status, completed_repetitions, exercise_code) values (?, ?, ?, ?, ?, ?, ?, 'completed', ?, ?)",
                    request.sessionId(), patientId, plan.get("id"), now, now, request.activeSeconds(),
                    request.correctnessRatio(), request.completedRepetitions(), request.exerciseCode());
        }
        jdbc.update("update patient_plan_items set status='completed', completed_at=? where id=? and patient_id=?",
                now, request.planItemId(), patientId);
        return Map.of("session_id", request.sessionId(), "plan_item_id", request.planItemId(),
                "status", "completed", "completed_repetitions", request.completedRepetitions());
    }
    public List<Map<String, Object>> devices(UUID patientId) { ensurePatient(patientId); return jdbc.queryForList("select * from patient_devices where patient_id=?", patientId).stream().map(this::deviceOutput).toList(); }
    public List<Map<String, Object>> exercises() { return jdbc.queryForList("select * from exercises where active=true order by category, code").stream().map(this::exerciseOutput).toList(); }
    public Map<String, Object> exercise(UUID exerciseId) { return exerciseOutput(jdbc.queryForMap("select * from exercises where id=? and active=true", exerciseId)); }
    public List<Map<String, Object>> notifications(UUID patientId) { return jdbc.queryForList("select id, severity, title, occurred_at, resolved_at from patient_alerts where patient_id=? order by occurred_at desc", patientId).stream().map(this::alertOutput).toList(); }
    public List<Map<String, Object>> alerts(UUID patientId, int limit) {
        return jdbc.queryForList("select id, severity, title, message, type, occurred_at, resolved_at from patient_alerts where patient_id=? order by occurred_at desc limit ?", patientId, limit)
                .stream().map(this::alertOutput).toList();
    }
    public void registerToken(UUID userId, String token, String platform) {
        var updated = jdbc.update("update fcm_tokens set platform=?, last_seen_at=? where user_id=? and token=?", platform, Timestamp.from(Instant.now()), userId, token);
        if (updated == 0) jdbc.update("insert into fcm_tokens (id,user_id,token,platform,last_seen_at) values (?,?,?,?,?)", UUID.randomUUID(), userId, token, platform, Timestamp.from(Instant.now()));
    }

    private Map<String,Object> homePlanOutput(Map<String,Object> p) {
        return Map.of("id", p.get("id"), "exercise_id", p.get("exercise_id"), "exercise_code", p.getOrDefault("exercise_code", ""), "exercise_name", p.get("exercise_name"), "image_asset", p.getOrDefault("image_asset", ""),
                "target", Map.of("kind", "repetitions", "sets", p.get("sets"), "repetitions_per_set", p.get("repetitions_per_set")),
                "assistance_level", p.get("assistance_level"), "estimated_duration_seconds", p.get("estimated_duration_seconds"));
    }

    private Map<String,Object> planOutput(Map<String,Object> p) { return Map.of("id", p.get("id"), "plan_id", p.getOrDefault("plan_id", p.get("id")), "exercise", Map.ofEntries(Map.entry("id", p.get("exercise_id")), Map.entry("code", p.getOrDefault("exercise_code", "")), Map.entry("name", p.get("exercise_name")), Map.entry("category", p.getOrDefault("exercise_category", "")), Map.entry("name_key", p.getOrDefault("name_key", "")), Map.entry("description_key", p.getOrDefault("description_key", "")), Map.entry("instructions_key", p.getOrDefault("instructions_key", "")), Map.entry("safety_key", p.getOrDefault("safety_key", "")), Map.entry("difficulty", p.getOrDefault("difficulty", "beginner")), Map.entry("requires_support", p.getOrDefault("requires_support", false)), Map.entry("image_asset", p.get("image_asset") == null ? "" : p.get("image_asset"))), "target", Map.of("kind", "repetitions", "sets", p.get("sets"), "repetitions_per_set", p.get("repetitions_per_set"), "rest_seconds", p.get("rest_seconds")), "safe_config", Map.of("assistance_level", p.get("assistance_level")), "status", p.get("status"), "estimated_duration_seconds", p.get("estimated_duration_seconds")); }
    private Map<String,Object> exerciseOutput(Map<String,Object> e) { return Map.ofEntries(Map.entry("id", e.get("id")), Map.entry("code", e.get("code")), Map.entry("name", e.get("name")), Map.entry("category", e.get("category")), Map.entry("name_key", e.getOrDefault("name_key", "")), Map.entry("description_key", e.getOrDefault("description_key", "")), Map.entry("instructions_key", e.getOrDefault("instructions_key", "")), Map.entry("safety_key", e.getOrDefault("safety_key", "")), Map.entry("difficulty", e.getOrDefault("difficulty", "beginner")), Map.entry("requires_support", e.getOrDefault("requires_support", false)), Map.entry("image_asset", e.get("image_asset") == null ? "" : e.get("image_asset"))); }
    private Map<String,Object> deviceOutput(Map<String,Object> d) { var readiness=new LinkedHashMap<String,Object>(); readiness.put("state",d.get("readiness_state")); readiness.put("blocking_reasons", d.get("blocking_reasons")==null||d.get("blocking_reasons").toString().isBlank()?List.of():List.of(d.get("blocking_reasons"))); var output=new LinkedHashMap<String,Object>(); output.put("id",d.get("id")); output.put("serial_number",d.get("serial_number")); output.put("model",d.get("model")); output.put("firmware_version",d.get("firmware_version")); output.put("protocol_version",d.get("protocol_version")); output.put("online",d.get("online")); output.put("last_seen_at",d.get("last_seen_at")); output.put("battery_percent",d.get("battery_percent")); output.put("readiness",readiness); output.put("health",Map.of("sensors",d.get("sensors_state"),"motors",d.get("motors_state"),"controller",d.get("controller_state"),"estop",d.get("estop_state"))); output.put("calibration",Map.of("status",d.get("calibration_status"),"expires_at",d.get("calibration_expires_at"))); return output; }
    private Map<String,Object> alertOutput(Map<String,Object> a) {
        var output = new LinkedHashMap<String, Object>();
        output.put("id", a.get("id"));
        output.put("severity", a.get("severity"));
        output.put("title", a.get("title"));
        output.put("message", a.getOrDefault("message", ""));
        output.put("type", a.getOrDefault("type", "general"));
        output.put("occurred_at", a.get("occurred_at"));
        output.put("resolved_at", a.get("resolved_at"));
        return output;
    }
}
