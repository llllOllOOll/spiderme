---
title: Modules
section: guide
order: 266
---

# Modules

A module is a package that plugs into an app through one contract. It says what it is, which versions of Spider it was tested with, which other modules it needs, which tables it brings and which variables it reads. Spider checks all of that when the app compiles, and again before the server listens: a module that does not fit does not compile, and one that is not ready keeps the server from starting, saying why.

The official modules live in the [spider-modules](https://github.com/llllOllOOll/spider-modules) repository. The first one is notify: notifications through an inbox, live pages, Web Push, FCM and email, with retries. Anyone can publish a module of their own, in any repository: [Writing a module](/docs/writing-modules).

The code on this page is from `examples/modules` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/modules)): an app with two modules, heartbeat, written for the example, and notify.

## Adding one

A module comes as a Zig package, and goes in `build.zig.zon` like any other dependency:

```zig from=examples/modules/build.zig.zon
```

spider-modules has no release tags yet, so the app pins a commit. `zig fetch` writes the two lines:

```bash
zig fetch --save=spider_modules "git+https://github.com/llllOllOOll/spider-modules#d99f79f78e29fac413170c92c8f879d9441d60d5"
```

Then `build.zig` gives the module the app's own `spider`:

```zig from=examples/modules/build.zig decl=notifyModule
```

and the app imports it under a name, in the `.imports` of the executable: `.{ .name = "spider_notify", .module = notify_mod }`.

A module never brings a Spider of its own. There is one Spider in the build, the app's, and every module gets it. That is why the app builds the module from its source file instead of taking something the package compiled.

## Mounting

Every module goes in one call to `mountModules`, before the features:

```zig from=examples/modules/src/main.zig decl=modules,serve
```

When the app compiles, `mountModules` checks each module's manifest, the exact signatures of what it declares, that no name is mounted twice, and that every module a module requires is in the same call, with no cycle between them. Then it works out the order they start in: a module after the ones it requires, and otherwise in the order given.

```zig from=examples/modules/src/order_test.zig decl=audit,billing decl="modules start after the modules they require"
```

Mounting them in two calls would hide their dependencies from each other, so `listen()` refuses it (`mountModules ran 2 times: mount every module in one call`).

What a module declares is mounted with it: its routes beside the app's, its jobs started by `listen()`. `spider routes` lists them with the app's own:

```text
GET     /                                                public
GET     /_spider/health                                  public  quiet_log
GET     /heartbeat                                       public  quiet_log
GET     /up                                              public  quiet_log
4 routes
1 background jobs, every: 1000ms
```

## Before the server listens

`listen()` runs the checks of every module before it opens the port. Spider's own come first: every variable the module requires is set and not blank, and its migrations are applied and unchanged. Then the module's own `check`, for what only the module knows. One problem is enough to stop the start, and every problem is listed:

```text
spider: 1 module(s) not ready, refusing to start
  heartbeat: HEARTBEAT_TOKEN is required but not set
```

`listen()` then returns `error.ModulesNotReady`. The test that runs heartbeat without its token:

```zig from=examples/modules/src/token_missing_test.zig decl="without HEARTBEAT_TOKEN the server refuses to start, and says why"
```

When every module is ready, the modules boot in their order, then the features. A deploy with a missing setting fails at once, on the server, instead of on the first request that needed it.

## Checking without starting

```bash
spider check --modules
```

It builds the app and runs it with `SPIDER_CHECK=1`: `listen()` prints the report and returns without serving. The exit status is 1 when a module is not ready, which makes it a step for CI or for a deploy script, run with the same environment as the app. (`spider check` alone checks the project's conventions; `--modules` does both.)

## A module with tables

notify keeps its data in PostgreSQL, so it brings migrations. The app needs `.pg = true` on the Spider dependency, and `spider.pg.init` before `listen()`. Without a database, the report says what is missing:

```zig from=examples/modules/src/notify_test.zig decl="notify without a database: the report says what to do"
```

On a database where they have not run yet, each migration is a problem, by name: `notify: migration notify/0001_init is not applied`. `spider migrate` applies them: the modules' first, in the order the modules start, then the app's own. Each runs in its own transaction with its row in `schema_migrations`, recorded as `module/name` with a checksum, so an edited migration is noticed. [Migrations in production](/docs/migrations) has the rest, and this test runs it on a disposable PostgreSQL (`examples/modules/test-db.sh`):

```zig from=examples/modules/src/db_test.zig decl="pending migrations keep the server from starting; migrate applies them, modules in start order"
```

What notify needs at boot (its channels, an address book) is in [its README](https://github.com/llllOllOOll/spider-modules/tree/main/notify).

## In tests

`server.check(arena, io)` runs the same checks and returns the report: `report.ok()`, `report.problems` (each with its `.module` and `.message`), `report.warnings`, and `report.write(w)` for the text `listen()` would log. A test can mount the modules on a server that never listens:

```zig from=examples/modules/src/order_test.zig decl=mailer decl="a required variable that is not set keeps the server from starting"
```

The module's routes and jobs are tested like the app's own, through `spider.testing.start`: [Testing](/docs/testing).

## Versions

A module says which versions of Spider it was tested with, as a range: `.spider = ">=0.11.0 <0.12.0"`. An app built with a Spider outside it does not compile:

```text
error: spider.module("old_widget"): supports Spider >=0.12.0 <0.13.0, but this is Spider 0.11.0
```

So after `spider update`, a module that was not tested with the new Spider stops the build until a version of it that was is out. The official modules are tested before Spider is: a release does not ship until every one of them passes on it, and their ranges are then widened to include it ([Writing a module](/docs/writing-modules) says how).
