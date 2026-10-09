-- migrate:up
CREATE TABLE IF NOT EXISTS posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    inserted_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TRIGGER IF NOT EXISTS posts_set_updated_at
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
    UPDATE posts SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- migrate:down
DROP TRIGGER IF EXISTS posts_set_updated_at;
DROP TABLE IF EXISTS posts;
