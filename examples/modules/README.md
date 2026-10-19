# Modules example

Not an app to deploy: what `content/docs/modules.md` and
`content/docs/writing-modules.md` show, kept as tests so that a page cannot
show code that stopped working.

    zig build test

- `heartbeat/` is a module in a package of its own, shaped as it would be
  in a repository of its own: a manifest, `check`, `boot`, `shutdown`, a
  job and a route, and its own tests (`cd heartbeat && zig build test`),
  which this build runs too.
- `src/main.zig` is an app that mounts it, with a feature of its own;
  `src/app_test.zig` asks the running app.
- `src/order_test.zig`: modules start after the ones they require; a
  required variable that is missing is reported.
- `src/notify_test.zig`: notify, from the spider-modules repository, wired
  the way an app wires it. It needs PostgreSQL to run; without a database
  the server says so before it starts, and that is what is tested.
- `src/token_missing_test.zig` and `src/token_short_test.zig` run with a bad
  `HEARTBEAT_TOKEN`: the server refuses to start.
- `src/compile_errors/` holds modules Spider refuses at compile time; the
  build checks that each fails with its message.
- `src/audit/` is a module with tables. `src/db_test.zig` applies its
  migrations and notify's on a PostgreSQL that exists for one run:

      ./test-db.sh

The site's own `zig build test` runs these too.
