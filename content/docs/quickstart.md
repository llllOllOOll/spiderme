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
```

It creates `src/features/posts/` with its routes, controller, views and a migration for the `posts` table. Open [localhost:3000/posts](http://localhost:3000/posts): `spider dev` rebuilt the app, and the app created the table when it started again.

## Run the tests

In another terminal:

```bash
zig build test
```

A new project already has tests, and one of them starts the app and asks it for a page. [Testing](/docs/testing) shows how to add yours.

## Add a login

```bash
spider g auth
```

It adds accounts, sign in and sign out. From then on every route says who may call it, the ones of `posts` included: [Login](/docs/auth) explains how.
