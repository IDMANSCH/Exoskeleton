CREATE TABLE IF NOT EXISTS motion_routines (
    id uuid PRIMARY KEY,
    patient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text NOT NULL DEFAULT '',
    repetitions integer NOT NULL DEFAULT 1 CHECK (repetitions BETWEEN 1 AND 100),
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'ready', 'archived')),
    version integer NOT NULL DEFAULT 1,
    definition_json jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS motion_routines_patient_idx
    ON motion_routines(patient_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS motion_routine_steps (
    id uuid PRIMARY KEY,
    routine_id uuid NOT NULL REFERENCES motion_routines(id) ON DELETE CASCADE,
    position integer NOT NULL CHECK (position >= 0),
    label text NOT NULL,
    motor text NOT NULL CHECK (motor IN ('C1', 'C2', 'C3', 'C4')),
    direction text NOT NULL CHECK (direction IN ('OUT', 'IN', 'STOP')),
    duration_ms integer NOT NULL CHECK (duration_ms BETWEEN 0 AND 30000),
    rest_after_ms integer NOT NULL CHECK (rest_after_ms BETWEEN 0 AND 10000),
    repeat_count integer NOT NULL DEFAULT 1 CHECK (repeat_count BETWEEN 1 AND 100),
    UNIQUE (routine_id, position)
);

CREATE INDEX IF NOT EXISTS motion_routine_steps_routine_idx
    ON motion_routine_steps(routine_id, position);
