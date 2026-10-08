CREATE TABLE IF NOT EXISTS user_notifications (
    id uuid PRIMARY KEY,
    recipient_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    data_json text NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now(),
    read_at timestamptz
);

CREATE INDEX IF NOT EXISTS user_notifications_recipient_idx
    ON user_notifications(recipient_user_id, created_at DESC);
