UPDATE exercises SET active = false
WHERE code IN ('supported_knee_raise', 'seated_knee_extension', 'heel_raises',
               'straight_leg_raise', 'heel_slides', 'quad_set', 'supported_hip_extension');
