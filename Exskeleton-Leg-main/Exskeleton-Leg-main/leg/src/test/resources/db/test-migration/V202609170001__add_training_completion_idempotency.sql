ALTER TABLE training_sessions
    ADD COLUMN IF NOT EXISTS completed_repetitions integer NOT NULL DEFAULT 0;

ALTER TABLE training_sessions
    ADD COLUMN IF NOT EXISTS exercise_code text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS training_sessions_patient_started_idx
    ON training_sessions(patient_id, started_at DESC);
