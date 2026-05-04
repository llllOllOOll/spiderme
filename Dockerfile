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

# Copy static assets
COPY --from=builder /app/public /app/public

# Copy views for runtime template mode (html + md only, no source)
COPY --from=builder /app/src /app/src
RUN find /app/src -name "*.zig" -delete

EXPOSE 3000

ENV LOG_LEVEL=warn

CMD ["./spiderme"]
