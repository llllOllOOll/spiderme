#!/usr/bin/env bash
# Runs the login examples (login/tests.zig) against a Keycloak that exists
# for this run: it is started from login/docker-compose.yml with the realm
# of login/realm.json, and removed when the tests end, whether they pass
# or not. Keycloak takes a minute or two to start.
#
#     ./login-test.sh
set -euo pipefail
cd "$(dirname "$0")"

compose() { docker compose -f login/docker-compose.yml -p guide-login "$@"; }
trap 'compose down --volumes >/dev/null 2>&1' EXIT

compose up -d >/dev/null
echo "waiting for Keycloak..."
for _ in $(seq 1 120); do
    curl -fsS -o /dev/null http://127.0.0.1:8189/realms/guide/.well-known/openid-configuration 2>/dev/null && break
    sleep 2
done

zig build test-login "$@"
