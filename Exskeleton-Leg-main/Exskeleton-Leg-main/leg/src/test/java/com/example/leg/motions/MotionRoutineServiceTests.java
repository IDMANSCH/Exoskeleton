package com.example.leg.motions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.example.leg.shared.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

class MotionRoutineServiceTests {
    private final MotionRoutineService service = new MotionRoutineService(null, null);

    @Test
    void compilesACompleteRightLegFlow() {
        var steps = service.validateAndNormalize(List.of(
                step("Nâng đùi", "C2", "OUT", 5000, 1000),
                step("Co gối", "C1", "OUT", 2000, 1000),
                step("Đá gối", "C1", "IN", 2500, 1000),
                step("Hạ đùi", "C2", "IN", 3000, 1000)), "ONE_LEG", "RIGHT");

        assertEquals(4, steps.size());
        assertEquals("C2", steps.get(0).get("motor"));
        assertEquals("IN", steps.get(3).get("direction"));
    }

    @Test
    void mirrorsTheWholeFlowForTwoLegMode() {
        var steps = service.validateAndNormalize(List.of(
                step("Co gối", "C1", "OUT", 2000, 1000),
                step("Duỗi gối", "C1", "IN", 2500, 1000)),
                "TWO_LEG_ALTERNATING", "RIGHT");

        assertEquals(4, steps.size());
        assertEquals(List.of("C1", "C1", "C3", "C3"),
                steps.stream().map(value -> value.get("motor")).toList());
    }

    @Test
    void rejectsRunningTheSameJointInTheSameDirectionTwice() {
        assertThrows(ApiException.class, () -> service.validateAndNormalize(List.of(
                step("Nâng", "C2", "OUT", 3000, 1000),
                step("Nâng tiếp", "C2", "OUT", 3000, 1000)),
                "ONE_LEG", "RIGHT"));
    }

    @Test
    void addsASevenSecondHomeAndEnoughReverseRest() {
        var steps = service.validateAndNormalize(List.of(
                step("Nâng", "C2", "OUT", 3000, 0)), "ONE_LEG", "RIGHT");

        assertEquals(2, steps.size());
        assertEquals(700, steps.get(0).get("rest_after_ms"));
        assertEquals(7000, steps.get(1).get("duration_ms"));
        assertEquals(true, steps.get(1).get("return_home"));
    }

    @Test
    void preservesBackendSelectedMotionDurations() {
        var steps = service.validateAndNormalize(List.of(
                step("Nâng đùi cao", "C2", "OUT", 4700, 900),
                step("Hạ đùi", "C2", "IN", 3200, 1000)),
                "ONE_LEG", "RIGHT");

        assertEquals(4700, steps.get(0).get("duration_ms"));
        assertEquals(3200, steps.get(1).get("duration_ms"));
    }

    @Test
    void motionLibraryUsesBackendDefaults() {
        var library = service.library();
        assertEquals(5000, library.get(0).get("duration_ms"));
        assertEquals(7000, library.get(1).get("duration_ms"));
        assertEquals(1000, library.get(1).get("default_rest_after_ms"));
    }

    private MotionRoutineService.StepRequest step(
            String label, String motor, String direction, int duration, int rest) {
        return new MotionRoutineService.StepRequest(label, motor, direction, duration, rest, 1);
    }
}
