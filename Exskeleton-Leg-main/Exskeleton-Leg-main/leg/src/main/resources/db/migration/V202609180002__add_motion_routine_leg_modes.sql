ALTER TABLE motion_routines
    ADD COLUMN IF NOT EXISTS execution_mode text NOT NULL DEFAULT 'ONE_LEG'
        CHECK (execution_mode IN ('ONE_LEG', 'TWO_LEG_ALTERNATING'));

ALTER TABLE motion_routines
    ADD COLUMN IF NOT EXISTS starting_side text NOT NULL DEFAULT 'RIGHT'
        CHECK (starting_side IN ('LEFT', 'RIGHT'));

ALTER TABLE motion_routine_steps
    ADD COLUMN IF NOT EXISTS return_home boolean NOT NULL DEFAULT false;
