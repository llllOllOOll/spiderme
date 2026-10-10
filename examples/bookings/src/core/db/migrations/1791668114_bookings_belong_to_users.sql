-- migrate:up
-- Who made the booking: the account. `booked_by` keeps the name shown.
ALTER TABLE bookings ADD COLUMN user_id BIGINT REFERENCES users (id) ON DELETE SET NULL;
CREATE INDEX bookings_by_user ON bookings (user_id, day);

-- migrate:down
ALTER TABLE bookings DROP COLUMN user_id;
