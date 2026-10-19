#!/usr/bin/env bash
# The modules' migrations on a PostgreSQL that exists only for this run
# (src/db_test.zig). Needs Docker.
#
#     ./test-db.sh
#
# TEST_PG_PORT (5564) and TEST_PG_CONTAINER (modules-example-test-db)
# change the port and the container's name, when something else uses them.
set -euo pipefail
cd "$(dirname "$0")"

port="${TEST_PG_PORT:-5564}"
name="${TEST_PG_CONTAINER:-modules-example-test-db}"
trap 'docker rm -f "$name" >/dev/null 2>&1' EXIT

docker run -d --name "$name" -p "$port:5432" --tmpfs /var/lib/postgresql/data \
    -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=modules_test postgres:17-alpine >/dev/null
until docker exec "$name" pg_isready -h 127.0.0.1 -U postgres -d modules_test >/dev/null 2>&1; do sleep 1; done

PG_HOST=127.0.0.1 PG_PORT="$port" PG_USER=postgres PG_PASSWORD=postgres PG_DB=modules_test \
    zig build test-db "$@"
