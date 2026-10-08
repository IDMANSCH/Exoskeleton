ALTER TABLE exercises ADD COLUMN IF NOT EXISTS image_asset text;

UPDATE exercises SET active = false
WHERE code IN ('supported_knee_raise', 'seated_knee_extension', 'heel_raises',
               'straight_leg_raise', 'heel_slides', 'quad_set', 'supported_hip_extension');

UPDATE exercises SET image_asset = 'assets/images/gen_assets/exercise_sit_to_stand.png' WHERE code = 'sit_to_stand';

INSERT INTO exercises (id, code, name, category, name_key, description_key, instructions_key, safety_key, difficulty, requires_support, image_asset) VALUES
    ('20000000-0000-0000-0000-000000000009', 'walk', 'Đi bộ', 'mobility', 'Exercises.Walk.Name', 'Exercises.Walk.Description', 'Exercises.Walk.Instructions', 'Exercises.Walk.Safety', 'beginner', true, 'assets/images/gen_assets/exercise_walk.png'),
    ('20000000-0000-0000-0000-000000000010', 'raise_left_leg', 'Nâng chân trái', 'strength', 'Exercises.RaiseLeftLeg.Name', 'Exercises.RaiseLeftLeg.Description', 'Exercises.RaiseLeftLeg.Instructions', 'Exercises.RaiseLeftLeg.Safety', 'beginner', true, 'assets/images/gen_assets/exercise_raise_left_leg.png'),
    ('20000000-0000-0000-0000-000000000011', 'raise_right_leg', 'Nâng chân phải', 'strength', 'Exercises.RaiseRightLeg.Name', 'Exercises.RaiseRightLeg.Description', 'Exercises.RaiseRightLeg.Instructions', 'Exercises.RaiseRightLeg.Safety', 'beginner', true, 'assets/images/gen_assets/exercise_raise_right_leg.png'),
    ('20000000-0000-0000-0000-000000000012', 'kick_left_leg', 'Đá chân trái', 'mobility', 'Exercises.KickLeftLeg.Name', 'Exercises.KickLeftLeg.Description', 'Exercises.KickLeftLeg.Instructions', 'Exercises.KickLeftLeg.Safety', 'beginner', true, 'assets/images/gen_assets/exercise_kick_left_leg.png'),
    ('20000000-0000-0000-0000-000000000013', 'kick_right_leg', 'Đá chân phải', 'mobility', 'Exercises.KickRightLeg.Name', 'Exercises.KickRightLeg.Description', 'Exercises.KickRightLeg.Instructions', 'Exercises.KickRightLeg.Safety', 'beginner', true, 'assets/images/gen_assets/exercise_kick_right_leg.png'),
    ('20000000-0000-0000-0000-000000000014', 'kick_left_knee', 'Đá đầu gối trái', 'mobility', 'Exercises.KickLeftKnee.Name', 'Exercises.KickLeftKnee.Description', 'Exercises.KickLeftKnee.Instructions', 'Exercises.KickLeftKnee.Safety', 'beginner', true, 'assets/images/gen_assets/exercise_kick_left_knee.png'),
    ('20000000-0000-0000-0000-000000000015', 'kick_right_knee', 'Đá đầu gối phải', 'mobility', 'Exercises.KickRightKnee.Name', 'Exercises.KickRightKnee.Description', 'Exercises.KickRightKnee.Instructions', 'Exercises.KickRightKnee.Safety', 'beginner', true, 'assets/images/gen_assets/exercise_kick_right_knee.png')
;
