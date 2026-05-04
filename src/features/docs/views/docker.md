-- doc

# Docker#

Spider compiles to a single binary with no runtime dependencies — perfect for Docker containers.

## Dockerfile#

```dockerfile
FROM alpine:3.19 AS builder

# Install Zig (0.17.0-dev or later)
RUN apk add --no-cache curl xz
RUN curl -sSL https://ziglang.org/download/0.17.0-dev/zig-linux-x86_64-0.17.0-dev.tar.xz | tar -xJ -C /usr/local/bin

WORKDIR /app
COPY . .

RUN zig build -Doptimize=ReleaseFast

# Final stage
FROM alpine:3.19

RUN apk add --no-cache libstdc++  # for Zig runtime

COPY --from=builder /app/zig-out/bin/myapp /usr/local/bin/app

EXPOSE 8080
CMD ["app"]
```

## Multi-stage Build#

For smaller images, use multi-stage build with caching:

```dockerfile
# Stage 1: Cache dependencies
FROM alpine:3.19 AS deps
RUN apk add --no-cache curl xz
RUN curl -sSL https://ziglang.org/download/0.17.0-dev/zig-linux-x86_64-0.17.0-dev.tar.xz | tar -xJ -C /usr/local/bin
WORKDIR /app
COPY build.zig.zon ./
RUN zig fetch

# Stage 2: Build
FROM deps AS builder
COPY . .
RUN zig build -Doptimize=ReleaseFast

# Stage 3: Runtime
FROM alpine:3.19
COPY --from=builder /app/zig-out/bin/myapp /usr/local/bin/app
EXPOSE 8080
CMD ["app"]
```

## Docker Compose#

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - PG_HOST=postgres
      - PG_USER=spider
      - JWT_SECRET=your-secret-here
    depends_on:
      - postgres

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: spider
      POSTGRES_PASSWORD: spider
      POSTGRES_DB: myapp
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

## Tips#

- Use `-Doptimize=ReleaseFast` for production builds
- Only `libstdc++` is needed at runtime (Zig's only runtime dependency)
- Set `SPIDER_ENV=production` to enable production mode
- Use `secure_cookie = true` in auth middleware for HTTPS
