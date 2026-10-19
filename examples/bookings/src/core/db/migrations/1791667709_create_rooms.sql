-- migrate:up
-- A room people book. `features` is a list: PostgreSQL has arrays, and
-- "rooms with a projector and a whiteboard" is one comparison on it.
--
-- Migrations run in the order of their file names, and the bookings
-- (1791667710_create_bookings) refer to this table, so it comes first. It
-- was called 1791667710_create_rooms while a list in the app gave the
-- order: IF NOT EXISTS lets a database made then record it under its new
-- name without making the table twice.
CREATE TABLE IF NOT EXISTS rooms (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    features TEXT[] NOT NULL DEFAULT '{}'
);

-- migrate:down
DROP TABLE IF EXISTS rooms;
