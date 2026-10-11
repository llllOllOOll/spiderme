---
title: Configuration
section: guide
order: 230
---

# Configuration

An app has two places for settings. What is the same everywhere goes in `spider.config.zig`, which is compiled in. What changes from one machine to another, and what is secret, goes in the environment.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)).

## spider.config.zig

```zig from=examples/posts/spider.config.zig
```

Everything has a default, so the file only lists what the app changes. The settings used most:

- `port` and `host`: where the app listens. `0.0.0.0` accepts connections from other machines, which a container needs.
- `views_dir`: the folder the templates are under.
- `static_dir`: the folder served as [static files](/docs/static). `null` serves none.
- `max_body_bytes`: the largest request body accepted, 10 MB unless you say otherwise. A bigger one is answered 413 before it is read.
- `require_route_access`: with `true`, the app refuses to start while a route does not say who may call it, and names each one.

## The environment

Variables come from the environment of the process, and from a file named `.env` in the folder the app runs in. `spider new` writes `.env` and keeps it out of git, with `.env.example` as the copy that is committed:

```text from=examples/posts/.env.example
```

When the same variable is in both, the environment wins over the file: that is how a server or a container sets its own values. A file named `.env.local`, if there is one, wins over `.env`, and never over the environment.

Spider reads a few variables itself:

- `PORT`: the port, in place of the one in `spider.config.zig`.
- `SQLITE_PATH`, or `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD` and `PG_DB`: the [database](/docs/database).
- `JWT_SECRET`: what [login](/docs/auth) sessions are signed with.

## Your own settings

`spider.env` reads a variable from the same places. Posts takes the key of its API from one:

```zig from=examples/posts/src/features/posts/api.zig decl=apiKey
```

`getOr` gives a default when the variable is not set; `get` gives null. Each call makes a copy of the value, which is why Posts reads its key once and keeps it.

## Secrets

Keep secrets in the environment, never in `spider.config.zig` or anywhere else in git. `.env` is for your own machine. In production, set the variables where the app runs: [Docker](/docs/docker) shows how to give them to a container.
