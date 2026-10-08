CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY,
    email_normalized text NOT NULL UNIQUE,
    password_hash text NOT NULL,
    display_name text NOT NULL,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'locked', 'deactivated')),
    locale text NOT NULL DEFAULT 'vi' CHECK (locale IN ('vi', 'en')),
    timezone text NOT NULL,
    accepted_terms_version text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE IF NOT EXISTS user_roles (
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('patient', 'caregiver', 'clinician', 'admin')),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, role)
);

CREATE TABLE IF NOT EXISTS refresh_sessions (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    family_id uuid NOT NULL,
    token_hash bytea NOT NULL UNIQUE,
    device_label text,
    expires_at timestamp with time zone NOT NULL,
    rotated_from_id uuid REFERENCES refresh_sessions(id),
    revoked_at timestamp with time zone,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS refresh_sessions_active_user_idx
    ON refresh_sessions (user_id, expires_at);

CREATE INDEX IF NOT EXISTS refresh_sessions_family_idx ON refresh_sessions (family_id);
