CREATE TABLE IF NOT EXISTS exercises (
    id uuid PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    category text NOT NULL,
    active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS patient_devices (
    id uuid PRIMARY KEY,
    patient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    serial_number text NOT NULL UNIQUE,
    model text NOT NULL,
    firmware_version text NOT NULL,
    protocol_version integer NOT NULL DEFAULT 1,
    online boolean NOT NULL DEFAULT false,
    last_seen_at timestamptz,
    battery_percent integer NOT NULL DEFAULT 0 CHECK (battery_percent BETWEEN 0 AND 100),
    readiness_state text NOT NULL DEFAULT 'unknown',
    blocking_reasons text NOT NULL DEFAULT '',
    sensors_state text NOT NULL DEFAULT 'unknown',
    motors_state text NOT NULL DEFAULT 'unknown',
    controller_state text NOT NULL DEFAULT 'unknown',
    estop_state text NOT NULL DEFAULT 'unknown',
    calibration_status text NOT NULL DEFAULT 'unknown',
    calibration_expires_at date
);

CREATE INDEX IF NOT EXISTS patient_devices_patient_idx ON patient_devices(patient_id);

CREATE TABLE IF NOT EXISTS patient_plan_items (
    id uuid PRIMARY KEY,
    patient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_id uuid NOT NULL REFERENCES exercises(id),
    plan_date date NOT NULL,
    sets integer NOT NULL CHECK (sets > 0),
    repetitions_per_set integer NOT NULL CHECK (repetitions_per_set > 0),
    rest_seconds integer NOT NULL DEFAULT 60,
    assistance_level text NOT NULL,
    estimated_duration_seconds integer NOT NULL,
    status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'skipped')),
    completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS patient_plan_items_patient_date_idx ON patient_plan_items(patient_id, plan_date);

CREATE TABLE IF NOT EXISTS training_sessions (
    id uuid PRIMARY KEY,
    patient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_item_id uuid REFERENCES patient_plan_items(id),
    started_at timestamptz NOT NULL,
    completed_at timestamptz,
    active_seconds integer NOT NULL DEFAULT 0,
    correctness_ratio numeric(5,4),
    status text NOT NULL DEFAULT 'completed'
);

CREATE TABLE IF NOT EXISTS patient_alerts (
    id uuid PRIMARY KEY,
    patient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    severity text NOT NULL,
    title text NOT NULL,
    occurred_at timestamptz NOT NULL,
    resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS patient_alerts_open_idx ON patient_alerts(patient_id, resolved_at, occurred_at);

CREATE TABLE IF NOT EXISTS fcm_tokens (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token text NOT NULL,
    platform text NOT NULL,
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(user_id, token)
);

INSERT INTO exercises (id, code, name, category) VALUES
    ('20000000-0000-0000-0000-000000000001', 'sit_to_stand', 'Đứng lên và ngồi xuống', 'strength'),
    ('20000000-0000-0000-0000-000000000002', 'supported_knee_raise', 'Nâng gối có hỗ trợ', 'mobility')
ON CONFLICT (code) DO NOTHING;
