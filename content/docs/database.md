---
title: Database
section: guide
order: 50
---

# Database

A new project uses SQLite: the data is one file, `db.sqlite`, next to the app, and there is nothing to install. `spider new myapp --pg` makes a project on PostgreSQL instead. [PostgreSQL](/docs/postgres) is about that.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)).

## Migrations

A migration is a SQL file that changes the database: it creates a table, adds a column. They live in `src/core/db/migrations/`, and `spider g feature` writes the first one of a feature. This is the one for the posts table:

```sql from=examples/posts/src/core/db/migrations/1791551321_create_posts.sql
```

The part after `-- migrate:up` is what runs. The number that starts the file name puts the migrations in order.

The app applies the migrations that have not run yet each time it starts, and remembers which ones ran, so each runs once. `spider migrate` does the same without starting the app.

To add one by hand, write the file and add it to the list in `src/core/db/migrations.zig`:

```zig from=examples/posts/src/core/db/migrations.zig decl=MIGRATIONS
```

A migration can also put rows in: the second one of Posts adds four posts, so a new copy of the app has something to show.

## Queries

A feature keeps its SQL in `repository.zig`. A row comes back as a struct: each column goes to the field with the same name.

```zig from=examples/posts/src/features/posts/model.zig decl=Post
```

`db.query` gives back every row, as a slice:

```zig from=examples/posts/src/features/posts/repository.zig decl=columns,list
```

Values never go into the SQL as text. They go in the last argument, and the SQL says where with `?1`, `?2` (in PostgreSQL, `$1`, `$2`):

```zig from=examples/posts/src/features/posts/repository.zig decl=search
```

`db.queryOne` gives back one row, or null when there is none:

```zig from=examples/posts/src/features/posts/repository.zig decl=find
```

To write, the same two functions. With `RETURNING`, an insert answers the row it made; a statement that answers nothing takes `void` as its type:

```zig from=examples/posts/src/features/posts/repository.zig decl=create,update,delete
```

The first argument after the type is where the result is kept. In a handler that is `c.arena`: memory of the request, freed when it ends.

## Where the database is

`SQLITE_PATH` in `.env` names the file; without it the app uses `db.sqlite`. The file is not kept in git.

A PostgreSQL project reads `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD` and `PG_DB` instead, and comes with a `docker-compose.yml` that starts a server for development:

```bash
docker compose up -d
```
