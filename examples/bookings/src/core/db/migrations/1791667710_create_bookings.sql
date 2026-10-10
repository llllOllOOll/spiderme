-- migrate:up
-- Needed by the rule below: it lets one constraint compare a plain column
-- (the room) and a range (the time) together.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE bookings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id BIGINT NOT NULL REFERENCES rooms (id) ON DELETE CASCADE,
    day DATE NOT NULL,
    starts TIME NOT NULL,
    ends TIME NOT NULL,
    title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
    note TEXT CHECK (char_length(note) <= 500),
    booked_by TEXT NOT NULL,
    -- held: waiting to be confirmed, until held_until. confirmed: kept.
    -- cancelled and expired: over; the time is free again.
    state TEXT NOT NULL DEFAULT 'held' CHECK (state IN ('held', 'confirmed', 'cancelled', 'expired')),
    held_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- The day runs from 08:00 to 20:00, in half hours.
    CONSTRAINT bookings_within_the_day CHECK (starts >= '08:00' AND ends <= '20:00' AND starts < ends),
    CONSTRAINT bookings_on_the_half_hour CHECK (
        extract(minute FROM starts) IN (0, 30) AND extract(minute FROM ends) IN (0, 30)
        AND extract(second FROM starts) = 0 AND extract(second FROM ends) = 0
    ),

    -- The rule of the whole app: a room cannot have two bookings at the same
    -- time. Only bookings that hold the room count (held or confirmed), and
    -- two that touch (one ends at 10:00, the next starts at 10:00) do not
    -- overlap. The database refuses the second one whoever asks and however
    -- close together the two requests arrive.
    CONSTRAINT bookings_do_not_overlap EXCLUDE USING gist (
        room_id WITH =,
        tsrange(day + starts, day + ends) WITH &&
    ) WHERE (state IN ('held', 'confirmed'))
);

CREATE INDEX bookings_by_day ON bookings (day, room_id);

-- migrate:down
DROP TABLE IF EXISTS bookings;
