---
title: PostgreSQL
section: guide
order: 60
---

# PostgreSQL

[Database](/docs/database) shows migrations and queries with SQLite, which is what a new project uses. This page is about a project on PostgreSQL: what changes, and what the database can then do for the app.

The code is from [Bookings](https://bookings.spiderme.org), the example app in `examples/bookings` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/bookings)): people book meeting rooms by the half hour, and a room cannot have two bookings at the same time.

## A project on PostgreSQL

```bash
spider new bookings --pg
cd bookings
docker compose up -d db
```

The project comes with a `docker-compose.yml` that runs PostgreSQL for development, and a `.env` that says where it is:

```text
PG_HOST=localhost
PG_PORT=5562
PG_USER=postgres
PG_PASSWORD=postgres
PG_DB=bookings_development
```

`main` opens the connections and applies the migrations before it serves:

```zig from=examples/bookings/src/main.zig decl=main
```

`db.init` opens a pool of connections, ten unless `.pool_size` says otherwise. Every query takes one from the pool and gives it back. What `.{}` leaves out comes from the `PG_*` variables.

## A rule the database keeps

A migration is a SQL file, as with SQLite. This one makes the bookings, and with them the rule of the whole app:

```sql from=examples/bookings/src/core/db/migrations/1791667710_create_bookings.sql
```

The last constraint is the rule: no two rows of the same room whose times overlap, counting only bookings that still hold the room. It is in the database on purpose. A check in the app ("is the room free? then insert") has a gap between the question and the insert, and two requests can both get through it. The constraint has no gap.

The `CHECK`s say the rest: a day runs from 08:00 to 20:00, in half hours, and a title is not empty.

## Rows as structs

A row comes back as a struct: each column goes to the field of the same name.

```zig from=examples/bookings/src/features/bookings/model.zig decl=State,Booking
```

```zig from=examples/bookings/src/features/bookings/repository.zig decl=columns,from,forDay
```

What to know about the types:

- A `[]const u8` field takes any column as text, so a date or a time is asked for the way the page shows it: `b.day::text`, `to_char(b.starts, 'HH24:MI')`.
- An enum field takes a text column (or a PostgreSQL enum) whose value is one of its names: `state` is `'held'`, the field is `State.held`.
- A column that can be `NULL` needs an optional field. `note: ?[]const u8` takes a missing note as `null`; a `NULL` into a field that is not optional is `error.UnexpectedNull`.
- A field with no column of its name is `error.ColumnMissing`, unless the field has a default.

Values go in the last argument and the SQL says where with `$1`, `$2`. A value is never written into the SQL text.

## Lists

PostgreSQL has arrays, and a room's features are one: a `TEXT[]` column. In the struct it is a slice, and the row fills it:

```zig from=examples/bookings/src/features/rooms/model.zig decl=Room
```

A slice of text takes a `TEXT[]`, a slice of `i64` a `BIGINT[]`, and so on. An empty array is an empty slice.

Going the other way, a list is one parameter, however many values it has. "Every room with a projector and a whiteboard" is one comparison:

```zig from=examples/bookings/src/features/rooms/repository.zig decl=columns,withFeatures
```

`db.array` also works with `= ANY($1)`: `WHERE id = ANY($1)` with a list of ids.

## Transactions

Each query may run on a different connection of the pool, so `BEGIN` in one query and `COMMIT` in another would not be one transaction: Spider refuses them with `error.UseBeginForTransactions`. A transaction is `db.transaction`: it takes one connection, runs the function, commits when it returns and rolls back when it fails.

Making a booking is two statements that must both happen or neither. A hold that ran out is released, then the new booking takes the time:

```zig from=examples/bookings/src/features/bookings/repository.zig decl=CreateError,create
```

Inside the function, queries go through `tx`, not `db`. `db.begin()` gives the same thing by hand: a `Transaction` with `query`, `queryOne`, `commit` and `rollback`.

## Errors by name

When PostgreSQL refuses a statement, the error says why by name. The ones an app meets most:

- `error.UniqueViolation`: a value that must be unique is there already.
- `error.ForeignKeyViolation`: the row points at one that does not exist, or is pointed at by one.
- `error.NotNullViolation`: a required column was left out.
- `error.CheckViolation`: a `CHECK` said no.
- `error.ExclusionViolation`: an `EXCLUDE` constraint said no.

The `catch` in `create` above turns them into the app's own errors: the `EXCLUDE` constraint refusing a row is `error.SlotTaken`, a `CHECK` is `error.InvalidBooking`. The handler then answers a visitor in the app's words, without knowing a constraint exists:

```zig from=examples/bookings/src/features/bookings/controller.zig decl=create
```

`db.lastError()` has the rest of what PostgreSQL said about the last failure: its code, its message, the constraint and the column. Its `detail` can hold values of the row: log it, do not show it.

## The same rule, twenty at once

A test asks for the same room and time from twenty threads. One gets it, nineteen are refused, and none fails any other way:

```zig from=examples/bookings/src/data_test.zig decl="twenty requests for the same time: exactly one gets it"
```

## Tests need a database too

The tests write to the database they are given, so it is never the development one. Bookings starts a PostgreSQL that exists for one run: its data is in memory, and the container is removed when the tests end, whether they pass or not.

```yaml from=examples/bookings/docker-compose.test.yml
```

```bash from=examples/bookings/test.sh
```

The tests connect to it the way `main` does, then ask the repositories and the pages:

```zig from=examples/bookings/src/app_test.zig decl=run
```

One thing to know: `zig build test` does not run a test again when nothing it was built from changed, and the database is not part of that. After changing only the database, change a source file or pass `--summary all` to see whether the tests ran.

## Let the database do the calendar

PostgreSQL knows weekdays, time zones and how to add a day. The day view asks it for everything it says about a day in one query, instead of doing that arithmetic in the app:

```zig from=examples/bookings/src/features/bookings/repository.zig decl=dayInfo
```
