package com.example.leg.motions;

import com.example.leg.shared.ApiException;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MotionRoutineService {
    private static final int MIN_REVERSE_REST_MS = 700;
    @Value("${exo.motion.thigh-raise-low-ms:5000}")
    private int thighRaiseLowMs = 5000;
    @Value("${exo.motion.thigh-raise-high-ms:7000}")
    private int thighRaiseHighMs = 7000;
    @Value("${exo.motion.thigh-lower-ms:5000}")
    private int thighLowerMs = 5000;
    @Value("${exo.motion.knee-bend-low-ms:5000}")
    private int kneeBendLowMs = 5000;
    @Value("${exo.motion.knee-kick-low-ms:5000}")
    private int kneeKickLowMs = 5000;
    @Value("${exo.motion.knee-kick-high-ms:7000}")
    private int kneeKickHighMs = 7000;
    @Value("${exo.motion.default-rest-after-ms:1000}")
    private int defaultRestAfterMs = 1000;
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public MotionRoutineService(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    @PostConstruct
    void validateMotionConfiguration() {
        for (int duration : List.of(thighRaiseLowMs, thighRaiseHighMs, thighLowerMs,
                kneeBendLowMs, kneeKickLowMs, kneeKickHighMs)) {
            if (duration < 1 || duration > 30000) {
                throw new IllegalStateException("EXO motion duration must be between 1 and 30000 ms");
            }
        }
        if (thighRaiseHighMs <= thighRaiseLowMs) {
            throw new IllegalStateException("High thigh duration must be greater than low thigh duration");
        }
        if (kneeKickHighMs <= kneeKickLowMs) {
            throw new IllegalStateException("High knee kick duration must be greater than low knee kick duration");
        }
        if (defaultRestAfterMs < MIN_REVERSE_REST_MS || defaultRestAfterMs > 10000) {
            throw new IllegalStateException("EXO default rest must be between 700 and 10000 ms");
        }
    }

    public List<Map<String, Object>> library() {
        return List.of(
                preset("thigh_raise_low", "Nâng đùi thấp", "C2", "OUT", thighRaiseLowMs, "right", "hip"),
                preset("thigh_raise_high", "Nâng đùi cao", "C2", "OUT", thighRaiseHighMs, "right", "hip"),
                preset("thigh_lower", "Hạ đùi", "C2", "IN", thighLowerMs, "right", "hip"),
                preset("knee_bend_low", "Co gối thấp", "C1", "OUT", kneeBendLowMs, "right", "knee"),
                preset("knee_kick_low", "Đá gối thấp", "C1", "IN", kneeKickLowMs, "right", "knee"),
                preset("knee_kick_high", "Đá gối cao", "C1", "IN", kneeKickHighMs, "right", "knee"),
                preset("left_thigh_raise_low", "Nâng đùi trái thấp", "C4", "OUT", thighRaiseLowMs, "left", "hip"),
                preset("left_thigh_raise_high", "Nâng đùi trái cao", "C4", "OUT", thighRaiseHighMs, "left", "hip"),
                preset("left_thigh_lower", "Hạ đùi trái", "C4", "IN", thighLowerMs, "left", "hip"),
                preset("left_knee_bend_low", "Co gối trái thấp", "C3", "OUT", kneeBendLowMs, "left", "knee"),
                preset("left_knee_kick_low", "Đá gối trái thấp", "C3", "IN", kneeKickLowMs, "left", "knee"),
                preset("left_knee_kick_high", "Đá gối trái cao", "C3", "IN", kneeKickHighMs, "left", "knee"));
    }

    private Map<String, Object> preset(String code, String label, String motor, String direction,
            int durationMs, String side, String joint) {
        return Map.of("code", code, "label", label, "motor", motor, "direction", direction,
                "duration_ms", durationMs, "default_rest_after_ms", defaultRestAfterMs,
                "side", side, "joint", joint);
    }

    @Transactional
    public Map<String, Object> create(UUID patientId, RoutineRequest request) {
        if (request.name() == null || request.name().isBlank()) invalid("Tên quy trình là bắt buộc.");
        if (request.repetitions() < 1 || request.repetitions() > 100) invalid("Số lần phải từ 1 đến 100.");
        if (request.steps() == null || request.steps().isEmpty() || request.steps().size() > 100) {
            invalid("Quy trình phải có từ 1 đến 100 bước.");
        }
        var mode = request.executionMode() == null ? "ONE_LEG" : request.executionMode().toUpperCase();
        var startingSide = request.startingSide() == null ? "RIGHT" : request.startingSide().toUpperCase();
        validateMode(mode, startingSide);
        var steps = validateAndNormalize(request.steps(), mode, startingSide);
        var id = UUID.randomUUID();
        var definition = new LinkedHashMap<String, Object>();
        definition.put("schema_version", 1);
        definition.put("routine_id", id.toString());
        definition.put("name", request.name().trim());
        definition.put("repetitions", request.repetitions());
        definition.put("execution_mode", mode);
        definition.put("starting_side", startingSide);
        definition.put("steps", steps);
        jdbc.update("insert into motion_routines (id, patient_id, name, description, repetitions, execution_mode, starting_side, status, version, definition_json, created_at, updated_at) values (?, ?, ?, ?, ?, ?, ?, 'ready', 1, ?::jsonb, ?, ?)",
                id, patientId, request.name().trim(), request.description() == null ? "" : request.description().trim(),
                request.repetitions(), mode, startingSide, json(definition), Timestamp.from(Instant.now()), Timestamp.from(Instant.now()));
        for (int i = 0; i < steps.size(); i++) {
            var step = steps.get(i);
            jdbc.update("insert into motion_routine_steps (id, routine_id, position, label, motor, direction, duration_ms, rest_after_ms, repeat_count, return_home) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    UUID.randomUUID(), id, i, step.get("label"), step.get("motor"), step.get("direction"),
                    step.get("duration_ms"), step.get("rest_after_ms"), step.get("repeat_count"), step.get("return_home"));
        }
        return get(patientId, id);
    }

    public List<Map<String, Object>> list(UUID patientId) {
        return jdbc.queryForList("select id, name, description, repetitions, status, version, created_at, updated_at from motion_routines where patient_id=? and status <> 'archived' order by updated_at desc", patientId);
    }

    public Map<String, Object> get(UUID patientId, UUID routineId) {
        var rows = jdbc.queryForList("select * from motion_routines where id=? and patient_id=?", routineId, patientId);
        if (rows.isEmpty()) throw new ApiException(HttpStatus.NOT_FOUND, "motion_routine.not_found", "Không tìm thấy quy trình.");
        var result = new LinkedHashMap<String, Object>(rows.get(0));
        result.put("steps", jdbc.queryForList("select position, label, motor, direction, duration_ms, rest_after_ms, repeat_count, return_home from motion_routine_steps where routine_id=? order by position", routineId));
        return result;
    }

    public Map<String, Object> dispatch(UUID patientId, UUID routineId) {
        var routine = get(patientId, routineId);
        var payload = new LinkedHashMap<String, Object>();
        payload.put("v", 1);
        payload.put("type", "routine_command");
        payload.put("routine_id", routineId.toString());
        payload.put("name", routine.get("name"));
        payload.put("repetitions", routine.get("repetitions"));
        payload.put("execution_mode", routine.get("execution_mode"));
        payload.put("starting_side", routine.get("starting_side"));
        payload.put("steps", routine.get("steps"));
        payload.put("safety", Map.of("direction_rest_ms", MIN_REVERSE_REST_MS, "max_step_duration_ms", 30000));
        return payload;
    }

    List<Map<String, Object>> validateAndNormalize(List<StepRequest> input, String mode, String startingSide) {
        var output = new ArrayList<Map<String, Object>>();
        var jointState = new HashMap<String, String>();
        var lastMotionDirection = new HashMap<String, String>();
        var lastMotionRest = new HashMap<String, Integer>();
        var usedMotors = new HashSet<String>();
        for (String motor : List.of("C1", "C2", "C3", "C4")) jointState.put(motor, "IN");
        for (int i = 0; i < input.size(); i++) {
            var step = input.get(i);
            if (!List.of("C1", "C2", "C3", "C4").contains(step.motor()) ||
                    !List.of("OUT", "IN", "STOP").contains(step.direction())) invalid("Bước " + (i + 1) + " có motor hoặc chiều không hợp lệ.");
            if (step.durationMs() < 0 || step.durationMs() > 30000 || step.restAfterMs() < 0 || step.restAfterMs() > 10000) invalid("Thời gian bước " + (i + 1) + " không hợp lệ.");
            if (step.repeatCount() < 1 || step.repeatCount() > 100) invalid("Số lần lặp bước " + (i + 1) + " không hợp lệ.");
            if (!"STOP".equals(step.direction()) && step.repeatCount() != 1) {
                invalid("Bước chuyển động chỉ được lặp một lần; hãy lặp toàn bộ quy trình.");
            }
            usedMotors.add(step.motor());
            var stepSide = sideOf(step.motor());
            // The client defines one complete leg flow. In two-leg mode the
            // server mirrors that whole flow after it has returned HOME.
            if (!startingSide.equals(stepSide)) {
                invalid("Flow gốc chỉ được dùng chân " + startingSide + ".");
            }
            var current = jointState.get(step.motor());
            if (!"STOP".equals(step.direction()) && current.equals(step.direction())) {
                invalid("Bước " + (i + 1) + " không hợp lệ: " + step.motor() + " đang ở " + current + ", không thể chạy cùng chiều tiếp.");
            }
            if (!"STOP".equals(step.direction()) && lastMotionDirection.containsKey(step.motor())
                    && !lastMotionDirection.get(step.motor()).equals(step.direction())
                    && lastMotionRest.getOrDefault(step.motor(), 0) < MIN_REVERSE_REST_MS) {
                    invalid("Bước " + (i + 1) + " đảo chiều nhưng thời gian nghỉ phải ít nhất 700ms.");
            }
            var row = new LinkedHashMap<String, Object>();
            row.put("label", step.label() == null || step.label().isBlank() ? step.motor() + " " + step.direction() : step.label().trim());
            row.put("motor", step.motor()); row.put("direction", step.direction()); row.put("duration_ms", step.durationMs());
            row.put("rest_after_ms", step.restAfterMs()); row.put("repeat_count", step.repeatCount());
            row.put("return_home", false);
            output.add(row);
            if (!"STOP".equals(step.direction())) jointState.put(step.motor(), step.direction());
            if (!"STOP".equals(step.direction())) {
                lastMotionDirection.put(step.motor(), step.direction());
                lastMotionRest.put(step.motor(), step.restAfterMs());
            }
        }
        // A routine is never allowed to finish in a raised/flexed position.
        // The server owns this invariant even if an older client omits the
        // explicit return-home cards.
        for (String motor : List.of("C1", "C2", "C3", "C4")) {
            if (!usedMotors.contains(motor)) continue;
            if ("OUT".equals(jointState.get(motor))) {
                for (int i = output.size() - 1; i >= 0; i--) {
                    var previous = output.get(i);
                    if (motor.equals(previous.get("motor")) && !"STOP".equals(previous.get("direction"))) {
                        previous.put("rest_after_ms", Math.max(
                                ((Number) previous.get("rest_after_ms")).intValue(), MIN_REVERSE_REST_MS));
                        break;
                    }
                }
                output.add(Map.of("label", motor + " về vị trí ban đầu", "motor", motor,
                        "direction", "IN", "duration_ms", homeDurationMs(motor),
                        "rest_after_ms", MIN_REVERSE_REST_MS, "repeat_count", 1,
                        "return_home", true));
            }
        }
        if ("TWO_LEG_ALTERNATING".equals(mode)) {
            var mirrored = new ArrayList<Map<String, Object>>();
            for (var step : output) {
                var copy = new LinkedHashMap<String, Object>(step);
                copy.put("motor", mirrorMotor((String) step.get("motor")));
                copy.put("label", "Đối bên • " + step.get("label"));
                mirrored.add(copy);
            }
            output.addAll(mirrored);
        }
        return output;
    }

    private int homeDurationMs(String motor) {
        return 7000;
    }

    private void validateMode(String mode, String side) {
        if (!List.of("ONE_LEG", "TWO_LEG_ALTERNATING").contains(mode)
                || !List.of("LEFT", "RIGHT").contains(side)) {
            invalid("Chế độ hoặc chân bắt đầu không hợp lệ.");
        }
    }

    private String sideOf(String motor) {
        return List.of("C1", "C2").contains(motor) ? "RIGHT" : "LEFT";
    }

    private String mirrorMotor(String motor) {
        return switch (motor) {
            case "C1" -> "C3";
            case "C2" -> "C4";
            case "C3" -> "C1";
            case "C4" -> "C2";
            default -> throw new IllegalArgumentException("Unsupported motor " + motor);
        };
    }

    private String json(Object value) { try { return objectMapper.writeValueAsString(value); } catch (JsonProcessingException e) { throw new IllegalStateException(e); } }
    private void invalid(String message) { throw new ApiException(HttpStatus.BAD_REQUEST, "motion_routine.invalid", message); }

    public record RoutineRequest(String name, String description, int repetitions,
            String executionMode, String startingSide, List<StepRequest> steps) {}
    public record StepRequest(String label, String motor, String direction, int durationMs, int restAfterMs, int repeatCount) {}
}
