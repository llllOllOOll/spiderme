#!/usr/bin/env bash
# Runs the tests against a PostgreSQL that exists only for this run.
#
#     ./test.sh            every test
#     ./test.sh --summary all   (anything after it goes to `zig build test`)
#
# The tests write to the database they are given, so it is never the
# development one: a container is started with its data in memory, and
# removed when the tests end, whether they pass or not. Needs Docker.
set -euo pipefail
cd "$(dirname "$0")"

compose() { docker compose -f docker-compose.test.yml -p bookings-test "$@"; }
trap 'compose down --volumes >/dev/null 2>&1' EXIT

compose up -d --wait >/dev/null

PG_HOST=127.0.0.1 PG_PORT=5563 PG_USER=postgres PG_PASSWORD=postgres PG_DB=bookings_test \
    zig build test "$@"
