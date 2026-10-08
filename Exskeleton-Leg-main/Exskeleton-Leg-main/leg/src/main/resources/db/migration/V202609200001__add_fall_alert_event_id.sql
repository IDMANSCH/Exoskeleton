ALTER TABLE patient_alerts ADD COLUMN IF NOT EXISTS source_event_id text;

CREATE UNIQUE INDEX IF NOT EXISTS patient_alerts_source_event_uidx
    ON patient_alerts(patient_id, source_event_id)
    WHERE source_event_id IS NOT NULL;
