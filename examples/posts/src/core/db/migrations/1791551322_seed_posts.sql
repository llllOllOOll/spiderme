-- migrate:up
-- A few posts so the first run has something to show.
INSERT INTO posts (title, author, inserted_at, body) VALUES
('Running Spider in a tiny container', 'Tom Becker', datetime('now', '-7 days'),
'The release binary carries its templates, so the image holds one file and needs one port.'),
('My first week with Zig 0.17', 'Priya Nair', datetime('now', '-3 days'),
'The compiler errors point at the right line. Allocators finally clicked once I started using the request arena.'),
('Server-rendered pages feel fast again', 'Marcus Lee', datetime('now', '-1 day'),
'I replaced a JSON API and a client framework with HTML views and htmx. Each page loads in one request and the JavaScript bundle is gone.'),
('Routes that read like a sentence', 'Ana Ribeiro', datetime('now', '-2 hours'),
'I rebuilt my side project''s router with Spider and kept the diff small. Every page is one line that names a path and a handler.

```
server
    .get("/posts", list, .{})
    .get("/posts/:id", show, .{})
```

## What I deleted

- The route table I used to keep in sync by hand.
- One controller function per page.
- Any doubt about what a handler receives, since the signature is the same everywhere.

The dynamic part, `/posts/:id`, reads straight from the path.');

-- migrate:down
DELETE FROM posts;
