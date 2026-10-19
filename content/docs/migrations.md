---
title: Migrations in production
section: guide
order: 285
---

# Migrations in production

An app on PostgreSQL keeps its migrations inside its binary. A server that runs the app needs nothing else to bring its database up to date: no command line tool, no SQL files beside it. This page is about what a run does, how to migrate a server, what keeps the app from starting, and how to move an older app to it.

A project on SQLite keeps its list of migrations, as [Database](/docs/database) shows, and nothing here concerns it. The code here is from [Bookings](https://bookings.spiderme.org), the example app in `examples/bookings` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/bookings)).

## In the binary

The migrations are the `.sql` files of `src/core/db/migrations/`. One line of `build.zig`, `spider.addMigrations(b, spider_dep, "src/core/db/migrations")` given to the executable as the import `migrations`, builds every one of them into the app. A file added there is in the binary after the next build. `main` hands them to the server and applies the ones that have not run, before it serves:

```zig from=examples/bookings/src/main.zig decl=migrations,main,migrate
```

`spider new --pg` writes all of this. Things to know about the files:

- They run in the order of their names. A name is at least four digits, `_`, and a description in lowercase letters, digits and `_`: `1791668113_create_users.sql`. Any other name does not compile.
- What runs is the part after `-- migrate:up` (or the whole file, without one) up to `-- migrate:down`. The down part never runs.

## What a run does

Each migration that has not run yet runs in a transaction of its own, together with its row in `schema_migrations`: it is applied and recorded, or neither. The row keeps a checksum of the SQL that ran.

Each migration takes a lock in the database before it looks for its row. Several copies of the app starting at the same time, as a deploy with more than one replica does, apply each migration once: the others wait for the lock, find the row, and go on.

A migration that fails is rolled back and stops the run; the ones before it stay applied. The app does not start.

## Migrating a server

```bash
SPIDER_MIGRATE=1 ./bookings
```

With `SPIDER_MIGRATE` set, the app migrates and exits instead of serving. Run it with the same environment as the app: the `PG_*` variables say which database. On a new database, Bookings prints:

```text
info: pg: connected (10 connections)
info: migration 1791667709_create_rooms applied
info: migration 1791667710_create_bookings applied
info: migration 1791667711_seed_rooms applied
info: migration 1791668113_create_users applied
info: migration 1791668114_bookings_belong_to_users applied
info: 5 migration(s) applied
```

In a container, the same image does it:

```bash
docker run --rm --env-file .env -e SPIDER_MIGRATE=1 myapp
```

On your machine, `spider migrate` builds the app and runs it that way (`zig build run` with `SPIDER_MIGRATE`). `spider.migrating()` tells `main` it is such a run, to skip what migrating does not need.

A project made by `spider new --pg` also migrates every time it starts, so deploying the new version is enough. Migrating as a step of its own is for when you want it apart: after a backup, once, before the new version starts on every replica.

## Never edit a migration that ran

The checksum is how Spider knows. A migration whose SQL is not what ran stops the run with `error.MigrationChanged`, and the app does not start: what changed belongs in a new migration.

## What keeps a server from starting

A server given the migrations with `.migrations(...)` checks them before it listens, and refuses to start while one has not run, naming it. `main` above gives them only to the server that migrates, since it migrates before every start. An app that migrates as a step of its own gives them to the server that serves as well, `server.migrations(migrations)`, and a version started on a database nobody migrated stops at once instead of failing on the first query. A test of Bookings gives a server one more file than the database has seen:

```zig from=examples/bookings/src/migrations_test.zig decl=migrations decl="a migration the database does not have keeps the server from starting"
```

## Going back to an older version

A rollback runs a binary older than its database: the database holds migrations this binary does not know. That is not a reason to refuse, or a rollback could never start. The app starts and says so:

```text
warning: app: the database holds 1 migration(s) this binary does not know (1791668114_bookings_belong_to_users): a newer version applied them; this one runs on a schema it was not built for
```

```zig from=examples/bookings/src/migrations_test.zig decl="a database ahead of the binary is a warning, not a refusal"
```

The same warning is a sign of a migration renamed by hand (below). Migrations only go forward: undoing one is a new migration in the next version.

## Moving an app made before

An app made before Spider 0.11 lists its migrations in `src/core/db/migrations.zig` and applies them with code of its own. To move it:

1. Add the `addMigrations` line to `build.zig` and make `main` look like the one above.
2. Delete `src/core/db/migrations.zig`, and `src/core/db/mod.zig` with the `db` line of `src/core/mod.zig` when that was all they held. From then on `spider g feature` only writes the `.sql` file.
3. Run it once on a copy of the production database before production.

The files keep working as they are:

- **The rows already there count.** A migration is recorded by its file name, as before, so nothing that ran runs again. The first run records the checksums of those rows: `info: recorded the checksums of 4 migration(s) applied before Spider kept them`.
- **A `BEGIN; ... COMMIT;` around a whole file** is left out: the transaction is Spider's. Any other transaction control is refused before anything runs.
- **A statement PostgreSQL refuses inside a transaction** (`CREATE INDEX CONCURRENTLY`) runs outside one, as long as it is alone in its file.

What can change is the order. The list ran migrations in the order it gave; the binary runs them in the order of their names. Bookings had two files made in the same second, `1791667710_create_bookings` and `1791667710_create_rooms`, listed with the rooms first. By name, the bookings come first, and they refer to the rooms: on a new database that migration fails. The fix was a new name, earlier, with `IF NOT EXISTS` for a database that already has the table:

```sql from=examples/bookings/src/core/db/migrations/1791667709_create_rooms.sql
```

On a database made before, the renamed migration only records itself, and the old row is one the binary does not know: the warning above, at every start, until the row goes. Delete it once, after the first run: `DELETE FROM schema_migrations WHERE version = '1791667710_create_rooms'`.

Before moving an app, read its list beside the file names. Where the orders differ, rename before anything else.

## In the tests

The tests run `main.migrate` on their own database, as `main` does ([PostgreSQL](/docs/postgres#Tests-need-a-database-too)), and check that the database and the binary agree:

```zig from=examples/bookings/src/migrations_test.zig decl="the migrations run once: a second run applies none" decl="the check finds every migration applied, under its file name"
```

## Modules

Modules bring migrations too, and the same run applies them: the modules' first, in the order the modules start, then the app's. Their rows are `module/name`, as `notify/0001_init`. [Modules](/docs/modules) shows it.
