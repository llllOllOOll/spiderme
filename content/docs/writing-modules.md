---
title: Writing a module
section: guide
order: 267
---

# Writing a module

A module is a package whose root file declares what it is, in a manifest, and may declare a check, a boot, a shutdown, jobs, routes and migrations. Spider holds each of those to an exact shape: a module that gets one wrong does not compile, in any app.

The code on this page is from `examples/modules` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/modules)). Its module, heartbeat, tells an uptime monitor that the app's background work is alive: a job beats once a second, and a route answers how many beats there have been, to whoever sends the right token. [Modules](/docs/modules) is about using one.

## The manifest

```zig from=examples/modules/heartbeat/src/heartbeat.zig decl=spider_module
```

- `.name`: lowercase letters, digits and `_`, starting with a letter, at most 64 bytes. Unique in the app.
- `.version`: the module's own version, `major.minor.patch`.
- `.spider`: the versions of Spider the module was tested with. One or more comparisons separated by spaces, all of which must hold: `>=0.11.0 <0.12.0`. `^` and `~` are not understood. Spider compares it with its own version, `spider.version`.
- `.requires`: other modules, by name. They start before this one, and must be mounted in the same call.
- `.migrations`: its tables, below.
- `.env`: the variables it reads. `.required` ones must be set, and not blank, for the server to start; `.optional` ones are there for the reader.

An unknown field does not compile.

## What does not compile

Every rule is checked when the app compiles, and the message names the module. The example keeps four modules that must fail, and its build checks each message: one tested with another Spider, a `boot` that Spider cannot call, a requirement that is not mounted, and migrations out of order:

```text
spider.module("old_widget"): supports Spider >=0.12.0 <0.13.0, but this is Spider 0.11.0
mountModules: module "late": boot must be `pub fn boot(b: spider.Boot) !void`
mountModules: module "billing" requires "audit", which is not mounted: add it to the same mountModules call
spider.module("audit"): migration "0001_init" comes after "0002_actor": list migrations in the order they run, without repeats
```

The second one:

```zig from=examples/modules/src/compile_errors/boot_signature.zig
```

The rest of the rules: a version that is not semver, a range that does not parse, a module that requires itself or names one twice, requirements in a cycle, the same module mounted twice, a variable name that is not `[A-Z][A-Z0-9_]*`, a `check` or `shutdown` with another signature, `jobs` that are not `spider.every`, and a function in `routes` that returns a `spider.Group` but takes parameters (skipping it would hide routes, so it is an error).

## check

```zig from=examples/modules/heartbeat/src/heartbeat.zig decl=check
```

`check` runs before the server listens, for every module, before any of them boots. Spider has already checked the variables in `.env.required` and the migrations; `check` is for what only the module knows: a setting that is set but wrong, two settings that disagree, a table it cannot read.

- `c.fail(format, args)` records a problem and the check goes on, so the report lists every one. Returning an error counts as one more.
- `c.env(name)` reads a variable, `c.arena` is memory for the check, `c.io` is for a query or a file.
- It must not change anything. `spider check --modules` runs it on a server that never starts.
- It does not run when Spider's own checks already failed for the module: it would only repeat the cause.

With a token of five characters:

```zig from=examples/modules/src/token_short_test.zig decl="a token too short: the module's own check keeps the server from starting"
```

## boot, shutdown, jobs and routes

```text
compile   manifests, signatures, the order the modules start in
listen()  every module's checks: a problem? refuse to start, listing them all
          boot(module 1) → boot(module 2) → … → the features' boot → serve
deinit()  the jobs stop → shutdown(module N) → … → shutdown(module 1)
```

```zig from=examples/modules/heartbeat/src/heartbeat.zig decl=boot,shutdown
```

- `boot` runs once, after every check passed, in the order the modules start, before the features' own `boot`. An error stops `listen()`, which returns it. It gets the same `spider.Boot` as a feature's: an allocator that lives as long as the process, and the server's `io`.
- `shutdown` runs from `server.deinit()`, after the jobs stopped, in the reverse order. It also runs for a module that never booted (a test that mounts it and stops), so it must not count on `boot` having run.

Jobs are a feature's jobs ([Scheduled jobs](/docs/jobs)): `listen()` starts them, and the first run comes one interval later.

```zig from=examples/modules/heartbeat/src/heartbeat.zig decl=every_ms,jobs,beat
```

Routes are a struct of functions that take nothing and return a `spider.Group`, as in a feature's `routes.zig`. Each route declares who may call it, as any route does ([Routing](/docs/router)). heartbeat's is public to the app's login and checks its own token instead:

```zig from=examples/modules/heartbeat/src/heartbeat.zig decl=routes,status
```

## Migrations

A module with tables lists its migrations in the manifest, in the order they run. The SQL lives in files of the package, one per migration, embedded when the app compiles:

```zig from=examples/modules/src/audit/audit.zig decl=spider_module
```

```sql from=examples/modules/src/audit/sql/0001_init.sql
```

- **Names** are at least four digits, `_` and a description in lowercase: `0001_init`. The row in `schema_migrations` is `audit/0001_init`, with a SHA-256 checksum of the SQL.
- **PostgreSQL, forward only.** The whole file runs; there is no down part.
- **No `BEGIN` or `COMMIT`.** Spider runs each migration in a transaction of its own, with its row. One that controls transactions is refused before anything runs (`error.MigrationHasTransactionControl`).
- **A statement that cannot run in a transaction** (`CREATE INDEX CONCURRENTLY`, `VACUUM`) must be alone in its migration, and then runs outside one.
- **Never edit a migration you released.** An applied migration whose SQL changed stops the migration and the start (`error.MigrationChanged`). Add the next one, as `0002_actor` adds a column:

```sql from=examples/modules/src/audit/sql/0002_actor.sql
```

- **A first migration that may meet a table an app made by hand** uses `CREATE ... IF NOT EXISTS`: applying it then only records it.

## Packaging

A module is a Zig package with its own `build.zig.zon`, and a real `fingerprint` (the first `zig build` suggests one). The package has **no dependency on Spider**: the app gives the module its own `spider`, so there is one Spider in the build.

A repository that also tests its module needs a Spider for those tests. It pins one as a lazy dependency, which only that repository's own build fetches:

```zig from=examples/modules/heartbeat/build.zig.zon
```

and its `build.zig` stops at once when it is not the build being run. An app that depends on the package then takes only the module's file; a second Spider in the app's build would clash with the app's (`file exists in modules 'spider' and 'spider0'`):

```zig from=examples/modules/heartbeat/build.zig decl=build
```

The app, for its part, builds the module from that file with its own `spider`:

```zig from=examples/modules/build.zig decl=heartbeatModule
```

The conventions of the official modules hold for anyone's: the package is called `spider_<name>`, and its README says how to install it, what to configure and what `check` prints when a variable is missing.

## Testing a module

Unit tests go next to the code. A test can also mount the module on a server that never listens and ask for the report, then play the lifecycle:

```zig from=examples/modules/heartbeat/src/heartbeat.zig decl="through Spider: ready with a token, and deinit runs shutdown"
```

`zig build test` in the package runs them on the Spider of its `build.zig.zon`. To run them on a Spider checkout instead, a release candidate or `main`:

```bash
zig build test --fork=../spider
```

Give `--fork` a path relative to the repository: Zig 0.17 refuses an absolute one for a package that has path dependencies of its own, as Spider does.

A module with tables also needs tests on a database, through Spider: not ready, migrated, ready. Run them on a PostgreSQL that exists for one run, never on a database you care about. `examples/modules/test-db.sh` does that for the test in [Modules](/docs/modules#A-module-with-tables).

## Publishing

Publish the package in any repository: apps fetch it by its address and pin it by its hash, as they do Spider. There is no registry.

- **Version.** Follow semver. Before 1.0 a breaking change raises the minor version, and goes in the changelog.
- **The Spider range** says what your tests passed on, not what you hope works. Widen it after the tests pass on the new Spider, never before.
- **The release gate.** The official modules in spider-modules come with `scripts/ecosystem.sh`, which builds and tests every one of them, database tests included, against a Spider checkout. Spider's CI runs it on every push and pull request to its `develop` and `main` branches, and a release runs it on the tag first: a release does not ship while an official module fails. When it passes on a new Spider, the modules' ranges are widened to include it.
- **A module of your own** is not part of that gate today. Spider's plan for modules (RFC 0001) has a list of third-party modules in the docs, and an opt-in to the same check, whose failures are reported to the module's authors and never block a release. Until then, run your tests against Spider's `main` in your own CI with `--fork`.
