ALTER TABLE exercises ADD COLUMN IF NOT EXISTS name_key varchar(255);
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS description_key varchar(255);
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS instructions_key varchar(255);
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS safety_key varchar(255);
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS difficulty varchar(32) NOT NULL DEFAULT 'beginner';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS requires_support boolean NOT NULL DEFAULT false;

UPDATE exercises SET name_key='Exercises.SitToStand.Name', description_key='Exercises.SitToStand.Description', instructions_key='Exercises.SitToStand.Instructions', safety_key='Exercises.SitToStand.Safety', difficulty='beginner', requires_support=true WHERE code='sit_to_stand';
UPDATE exercises SET name_key='Exercises.SupportedKneeRaise.Name', description_key='Exercises.SupportedKneeRaise.Description', instructions_key='Exercises.SupportedKneeRaise.Instructions', safety_key='Exercises.SupportedKneeRaise.Safety', difficulty='beginner', requires_support=true WHERE code='supported_knee_raise';

INSERT INTO exercises (id, code, name, category, name_key, description_key, instructions_key, safety_key, difficulty, requires_support) VALUES
    ('20000000-0000-0000-0000-000000000003', 'seated_knee_extension', 'Duỗi gối khi ngồi', 'mobility', 'Exercises.SeatedKneeExtension.Name', 'Exercises.SeatedKneeExtension.Description', 'Exercises.SeatedKneeExtension.Instructions', 'Exercises.SeatedKneeExtension.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000004', 'heel_raises', 'Nhón gót có điểm tựa', 'strength', 'Exercises.HeelRaises.Name', 'Exercises.HeelRaises.Description', 'Exercises.HeelRaises.Instructions', 'Exercises.HeelRaises.Safety', 'beginner', true),
    ('20000000-0000-0000-0000-000000000005', 'straight_leg_raise', 'Nâng chân thẳng', 'strength', 'Exercises.StraightLegRaise.Name', 'Exercises.StraightLegRaise.Description', 'Exercises.StraightLegRaise.Instructions', 'Exercises.StraightLegRaise.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000006', 'heel_slides', 'Trượt gót chân', 'mobility', 'Exercises.HeelSlides.Name', 'Exercises.HeelSlides.Description', 'Exercises.HeelSlides.Instructions', 'Exercises.HeelSlides.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000007', 'quad_set', 'Siết cơ đùi tĩnh', 'strength', 'Exercises.QuadSet.Name', 'Exercises.QuadSet.Description', 'Exercises.QuadSet.Instructions', 'Exercises.QuadSet.Safety', 'beginner', false),
    ('20000000-0000-0000-0000-000000000008', 'supported_hip_extension', 'Duỗi hông có điểm tựa', 'strength', 'Exercises.SupportedHipExtension.Name', 'Exercises.SupportedHipExtension.Description', 'Exercises.SupportedHipExtension.Instructions', 'Exercises.SupportedHipExtension.Safety', 'beginner', true)
;
