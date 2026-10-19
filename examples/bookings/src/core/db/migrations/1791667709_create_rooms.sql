-- migrate:up
-- A room people book. `features` is a list: PostgreSQL has arrays, and
-- "rooms with a projector and a whiteboard" is one comparison on it.
CREATE TABLE rooms (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    features TEXT[] NOT NULL DEFAULT '{}'
);

-- migrate:down
DROP TABLE IF EXISTS rooms;
