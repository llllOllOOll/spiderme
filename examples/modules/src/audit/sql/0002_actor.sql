-- A released migration is never edited: what changed comes as a new one.
ALTER TABLE audit_events ADD COLUMN actor TEXT;
