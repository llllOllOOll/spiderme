---
title: Quick start
section: start
order: 10
---

# Quick start

Spider is a web framework for Zig: a router, templates, a database driver and a command line tool that creates the project for you.

You need **Zig 0.17.0**, the official release, from [ziglang.org/download](https://ziglang.org/download/).

## Install the command line tool

```bash
curl -fsSL https://raw.githubusercontent.com/llllOllOOll/spider/main/scripts/install.sh | bash
```

It installs `spider` in `~/.local/bin`.

## Create an app

```bash
spider new myapp
cd myapp
spider dev
```

By default `spider new` writes a project with HTML views and a SQLite database. `spider new myapp --pg` uses PostgreSQL instead, and `--no-db` leaves the database out.

`spider dev` builds the app, runs it on [localhost:3000](http://localhost:3000) and, each time you save a file, rebuilds and reloads the browser.

## Add a feature

```bash
spider g feature posts
spider migrate
```

The first command creates `src/features/posts/` with its routes, controller, views and a migration. The second applies the migration.
