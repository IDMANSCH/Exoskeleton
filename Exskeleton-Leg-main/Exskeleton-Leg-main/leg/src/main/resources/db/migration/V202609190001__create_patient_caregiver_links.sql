CREATE TABLE IF NOT EXISTS patient_caregiver_links (
    id uuid PRIMARY KEY,
    patient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    caregiver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'rejected', 'revoked')),
    requested_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (patient_id, caregiver_id),
    CHECK (patient_id <> caregiver_id)
);

CREATE INDEX IF NOT EXISTS patient_caregiver_patient_idx
    ON patient_caregiver_links(patient_id, status);
CREATE INDEX IF NOT EXISTS patient_caregiver_caregiver_idx
    ON patient_caregiver_links(caregiver_id, status);

ALTER TABLE patient_alerts ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'general';
ALTER TABLE patient_alerts ADD COLUMN IF NOT EXISTS message text NOT NULL DEFAULT '';
