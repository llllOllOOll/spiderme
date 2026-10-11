---
title: Docker
section: guide
order: 220
---

# Docker

`spider new` writes a `Dockerfile` and a `.dockerignore` at the root of the project.

## Build and run

```bash
docker build -t myapp .
docker run -p 3000:3000 myapp
```

The app listens on port 3000 inside the container.

`.env` is not copied into the image, so the settings in it have to be given when the container starts:

```bash
docker run -p 3000:3000 --env-file .env myapp
```

An app with a [login](/docs/auth) needs this: a release build refuses to sign anyone in without `JWT_SECRET`.

## What the Dockerfile does

It has two stages.

The first builds the app. It downloads the official Zig release and checks it against its published checksum, installs the `spider` command, copies the project and runs:

```bash
zig build -Doptimize=ReleaseSmall
```

The second is the image you run. It holds two things: the binary and the `public` folder. Templates are not copied, because a release build keeps them inside the binary.

## What stays out of the image

The `.dockerignore` keeps `.env`, the SQLite database and your local build out of the build. Tailwind, the icons, htmx and Alpine are not in git either: the build downloads them again, for the image's own system.

## Another port

The app reads the `PORT` variable:

```bash
docker run -p 8080:8080 -e PORT=8080 myapp
```

## The database

The app applies its migrations when it starts, so a new container has its tables on the first request.

With SQLite the data is a file inside the container, and it goes away with the container. To keep it, put the file in a volume:

```bash
docker run -p 3000:3000 -v myapp-data:/data -e SQLITE_PATH=/data/db.sqlite myapp
```

## PostgreSQL

A project created with `--pg` also gets a `docker-compose.yml`. It does not run the app: it starts a PostgreSQL server for development, on the port written in `.env`.

```bash
docker compose up -d
```
