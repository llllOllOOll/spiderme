---
title: Development
section: start
order: 20
---

# Development

```bash
spider dev
```

It builds the app, runs it, and keeps watching the project. Save a file and the browser shows the change. It is the command to leave running while you work.

## What happens when you save

- **A template** (`.html`): nothing is rebuilt. Templates are read from disk on every request in development, and the browser reloads.
- **A stylesheet**: the CSS is compiled again and the browser reloads. The app keeps running.
- **A Zig file**: the app is rebuilt and started again, then the browser reloads. Only what changed is compiled, so this takes about a second.

The browser reloads by itself because, under `spider dev`, the app adds a small script to every page. A release build never has it.

## When the code does not compile

The error is printed in the terminal, and the app that was running stays up, with the last version that compiled. Fix the error and save: the new version takes over.

## The port

The app listens where `spider.config.zig` says, 3000 in a new project. To use another port for one run:

```bash
spider dev --port 4000
```

## Other commands while it runs

Open another terminal. `zig build test`, `spider g feature`, `spider routes` and the rest work next to `spider dev`; what they change is picked up like any save.

Only one `spider dev` runs in a project at a time. A second one says so and stops.

## Good to know

- Stop it with Ctrl+C.
- `spider dev` keeps its build in `.zig-cache/dev`, apart from the one `zig build` uses. The first run compiles everything; the next ones start quickly.
- On Linux x86_64 the build is incremental. On other systems it rebuilds the app on each save, which takes longer.
- With a [login](/docs/auth) and no `JWT_SECRET` in `.env`, everyone is signed out each time the app restarts. `spider new` writes one, so this only happens if it was removed.
