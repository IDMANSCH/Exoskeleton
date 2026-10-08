ALTER TABLE exercises ADD COLUMN IF NOT EXISTS name_key text;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS description_key text;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS instructions_key text;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS safety_key text;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS difficulty text NOT NULL DEFAULT 'beginner';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS requires_support boolean NOT NULL DEFAULT false;

INSERT INTO exercises (id, code, name, category, name_key, description_key, instructions_key, safety_key, difficulty, requires_support) VALUES
    ('20000000-0000-0000-0000-000000000001', 'sit_to_stand', 'Đứng lên và ngồi xuống', 'strength', 'Exercises.SitToStand.Name', 'Exercises.SitToStand.Description', 'Exercises.SitToStand.Instructions', 'Exercises.SitToStand.Safety', 'beginner', true),
    ('20000000-0000-0000-0000-000000000002', 'supported_knee_raise', 'Nâng gối có hỗ trợ', 'mobility', 'Exercises.SupportedKneeRaise.Name', 'Exercises.SupportedKneeRaise.Description', 'Exercises.SupportedKneeRaise.Instructions', 'Exercises.SupportedKneeRaise.Safety', 'beginner', true),
    ('20000000-0000-0000-0000-000000000003', 'seated_knee_extension', 'Duỗi gối khi ngồi', 'mobility', 'Exercises.SeatedKneeExtension.Name', 'Exercises.SeatedKneeExtension.Description', 'Exercises.SeatedKneeExtension.Instructions', 'Exercises.SeatedKneeExtension.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000004', 'heel_raises', 'Nhón gót có điểm tựa', 'strength', 'Exercises.HeelRaises.Name', 'Exercises.HeelRaises.Description', 'Exercises.HeelRaises.Instructions', 'Exercises.HeelRaises.Safety', 'beginner', true),
    ('20000000-0000-0000-0000-000000000005', 'straight_leg_raise', 'Nâng chân thẳng', 'strength', 'Exercises.StraightLegRaise.Name', 'Exercises.StraightLegRaise.Description', 'Exercises.StraightLegRaise.Instructions', 'Exercises.StraightLegRaise.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000006', 'heel_slides', 'Trượt gót chân', 'mobility', 'Exercises.HeelSlides.Name', 'Exercises.HeelSlides.Description', 'Exercises.HeelSlides.Instructions', 'Exercises.HeelSlides.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000007', 'quad_set', 'Siết cơ đùi tĩnh', 'strength', 'Exercises.QuadSet.Name', 'Exercises.QuadSet.Description', 'Exercises.QuadSet.Instructions', 'Exercises.QuadSet.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000008', 'supported_hip_extension', 'Duỗi hông có điểm tựa', 'strength', 'Exercises.SupportedHipExtension.Name', 'Exercises.SupportedHipExtension.Description', 'Exercises.SupportedHipExtension.Instructions', 'Exercises.SupportedHipExtension.Safety', 'beginner', true)
ON CONFLICT (code) DO UPDATE SET
    name_key = EXCLUDED.name_key,
    description_key = EXCLUDED.description_key,
    instructions_key = EXCLUDED.instructions_key,
    safety_key = EXCLUDED.safety_key,
    difficulty = EXCLUDED.difficulty,
    requires_support = EXCLUDED.requires_support;
