---
title: Command line tool
section: reference
order: 5
---

# Command line tool

`spider` creates a project, runs it while you work, and generates code inside it. Every command has its own help: `spider help new`, or `spider new --help`.

## Install and update

```bash
curl -fsSL https://raw.githubusercontent.com/llllOllOOll/spider/main/scripts/install.sh | bash
```

`spider version` prints the version installed, and `spider self-update` installs the latest one.

## Create a project

```bash
spider new myapp
```

It writes the project to `./myapp`, with HTML views and a SQLite database.

- `--pg` uses PostgreSQL instead of SQLite.
- `--no-db` leaves the database out.
- `--api` makes a JSON project, without HTML views.
- `--ui=tailwind` uses plain Tailwind instead of daisyUI.
- `--pwa` makes the app installable, with a manifest and a service worker.

## Work on it

Run these inside the project.

- `spider dev` builds the app, runs it, and after every save rebuilds it and reloads the browser. `--port 4000` changes the port.
- `spider g feature posts` generates `src/features/posts/` with a controller, a model, a repository, routes, views and a migration.
- `spider migrate` applies the migrations that have not run yet.
- `spider routes` lists every route with its method, its path and who may call it.
- `spider check` reports what does not follow the project's conventions, with the file, the line and the fix.

## Assets

- `spider install` downloads Tailwind, htmx, Alpine and the icon sets into the project. A new project has them already, and they are not committed to git.
- `spider ui` shows the UI kit in use; `spider ui use tailwind` switches it.
- `spider icons` shows the icon sets in use; `spider icons add lucide` adds one.

## Keep Spider up to date

`spider update` moves the project to the latest Spider. It changes `build.zig.zon`, so read the changelog before you run it.
