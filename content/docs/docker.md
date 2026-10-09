---
title: Docker
section: guide
order: 60
---

# Docker

`spider new` writes a `Dockerfile` at the root of the project. It builds the app in one stage and copies the result into a small image.

```dockerfile
FROM llllollooll/zig:master AS builder
WORKDIR /app
COPY . .
RUN zig build -Doptimize=ReleaseSmall

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/zig-out/bin/myapp /app/myapp
COPY --from=builder /app/public /app/public
EXPOSE 3000
CMD ["./myapp"]
```

The final image holds two things: the binary and the `public` folder. Templates are not copied, because a release build keeps them inside the binary.

## Build and run

```bash
docker build -t myapp .
docker run -p 3000:3000 myapp
```

The app listens on port 3000 inside the container.

## Known problem in 0.9.0

With Spider 0.9.0 the `builder` image above is behind: it carries a Zig older than 0.17.0, and the build stops at `zig build`. Until the generated file changes, replace the first line with an image that has the official Zig 0.17.0.

## The compose file

`docker-compose.yml` does not run the app. It starts a PostgreSQL server for development, for projects created with `--pg`:

```bash
docker compose up -d
```
