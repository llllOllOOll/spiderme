-- migrate:up
-- The rooms of the example, so that the day view has something to show.
INSERT INTO rooms (name, capacity, features) VALUES
    ('Atlas', 12, '{projector,video call,whiteboard}'),
    ('Birch', 6, '{screen,whiteboard}'),
    ('Cedar', 4, '{screen}'),
    ('Delta', 8, '{projector,video call}'),
    ('Echo (phone booth)', 1, '{}'),
    ('Workshop', 20, '{projector,whiteboard,movable tables}')
ON CONFLICT (name) DO NOTHING;

-- migrate:down
DELETE FROM rooms WHERE name IN ('Atlas', 'Birch', 'Cedar', 'Delta', 'Echo (phone booth)', 'Workshop');
