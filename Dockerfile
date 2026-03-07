FROM llllollooll/zig:master AS builder

WORKDIR /app

COPY . .

RUN apt-get update && apt-get install -y --no-install-recommends libpq-dev
RUN zig build -Doptimize=ReleaseSmall

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends libpq5 curl

WORKDIR /app

# Copy the binary
COPY --from=builder /app/zig-out/bin/spiderme /app/spiderme

# Copy static assets (critical for /assets/* routes)
COPY --from=builder /app/assets /app/assets

# Ensure assets are readable and directories are traversable
RUN find /app/assets -type d -exec chmod 755 {} \; && \
    find /app/assets -type f -exec chmod 644 {} \;

EXPOSE 3000

CMD ["./spiderme"]
