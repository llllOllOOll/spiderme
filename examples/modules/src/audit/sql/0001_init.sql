-- The module's table. No BEGIN/COMMIT: Spider runs each migration in a
-- transaction of its own. IF NOT EXISTS: an app that made this table by
-- hand before only records the migration.
CREATE TABLE IF NOT EXISTS audit_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action TEXT NOT NULL,
    at TIMESTAMPTZ NOT NULL DEFAULT now()
);
