#!/usr/bin/env bash
# Deploys the site to its server.
#
#     ./deploy.sh             build, send, start the new version, retire the old one
#     ./deploy.sh status      what is running on the server
#     ./deploy.sh rollback    go back to the version before the current one
#
# How it works. The image is built here and sent to the server over SSH
# (no registry in between). On the server, a Traefik that is already there
# routes by the labels of each container. The new version starts next to
# the old one; when it answers /up, the old one is removed. If it never
# answers, it is removed instead and the old one keeps serving.
#
# It needs: Docker here, and SSH access to the server as a user that can
# run `docker` there. Nothing secret is in this file or in the image.
set -euo pipefail
cd "$(dirname "$0")"

# ── settings ────────────────────────────────────────────────────────────
SERVER="${DEPLOY_SERVER:-seven@spiderme.org}"
APP="spiderme-site"                      # image name, container prefix, Traefik names
RULE='Host(`spiderme.org`) || Host(`www.spiderme.org`)'
NETWORK="network_public"                 # the Docker network Traefik watches
CERT_RESOLVER="letsencrypt"              # the name of Traefik's certificate resolver
CHECK_URL="https://spiderme.org"         # where the public sees it
KEEP_IMAGES=3                            # versions kept on the server for rollback
# A container of the site started by hand before this script existed.
LEGACY_CONTAINER="spiderme-app"

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

# Runs the functions below on the server. They only touch containers and
# images of this app.
remote() {
    # shellcheck disable=SC2029
    ssh -o BatchMode=yes "$SERVER" "APP='$APP' NETWORK='$NETWORK' CERT_RESOLVER='$CERT_RESOLVER' KEEP_IMAGES='$KEEP_IMAGES' LEGACY_CONTAINER='$LEGACY_CONTAINER' RULE='$RULE' bash -s -- $*" <<'REMOTE'
set -euo pipefail

# The containers of this app, newest first.
containers() { docker ps -a --filter "label=deploy.app=$APP" --format '{{.Names}}' ; }

start() {
    local version="$1" name="$APP-$1"
    docker rm -f "$name" >/dev/null 2>&1 || true
    docker run -d \
        --name "$name" \
        --restart unless-stopped \
        --network "$NETWORK" \
        --label "deploy.app=$APP" \
        --label "deploy.version=$version" \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.$APP.rule=$RULE" \
        --label "traefik.http.routers.$APP.entrypoints=websecure" \
        --label "traefik.http.routers.$APP.tls=true" \
        --label "traefik.http.routers.$APP.tls.certresolver=$CERT_RESOLVER" \
        --label "traefik.http.services.$APP.loadbalancer.server.port=3000" \
        --label "traefik.http.services.$APP.loadbalancer.healthcheck.path=/up" \
        --label "traefik.http.services.$APP.loadbalancer.healthcheck.interval=5s" \
        --label "traefik.http.services.$APP.loadbalancer.healthcheck.timeout=3s" \
        "$APP:$version" >/dev/null

    # Ask the container itself, not Traefik: is it answering?
    local ip=""
    for _ in $(seq 1 30); do
        ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null || true)"
        if [ -n "$ip" ] && curl -fsS -m 3 -o /dev/null "http://$ip:3000/up"; then
            echo "started $name"
            # Traefik sends it requests after its own first check of /up
            # (every 5s, see the labels). Until then the old one serves.
            sleep 8
            return 0
        fi
        sleep 1
    done
    echo "the new version did not answer /up; its last lines:" >&2
    docker logs --tail 30 "$name" >&2 || true
    docker rm -f "$name" >/dev/null 2>&1 || true
    return 1
}

# Removes every container of the app except the one of `version`.
retire_others() {
    local keep="$APP-$1"
    for name in $(containers) "$LEGACY_CONTAINER"; do
        [ "$name" = "$keep" ] && continue
        if docker inspect "$name" >/dev/null 2>&1; then
            docker rm -f "$name" >/dev/null && echo "removed $name"
        fi
    done
}

# Keeps the newest KEEP_IMAGES versions of the image.
prune_images() {
    docker images "$APP" --format '{{.Tag}}' | sort -r | tail -n +"$((KEEP_IMAGES + 1))" | while read -r tag; do
        docker rmi "$APP:$tag" >/dev/null 2>&1 && echo "removed image $APP:$tag" || true
    done
}

case "$1" in
    switch)
        start "$2"
        retire_others "$2"
        prune_images
        ;;
    current)
        docker ps --filter "label=deploy.app=$APP" --format '{{.Label "deploy.version"}}' | head -n 1
        ;;
    versions)
        docker images "$APP" --format '{{.Tag}}' | sort -r
        ;;
    status)
        echo "containers:"
        docker ps -a --filter "label=deploy.app=$APP" --format '{{.Names}}  {{.Status}}' | sed 's/^/  /'
        docker ps -a --filter "name=^${LEGACY_CONTAINER}$" --format '{{.Names}}  {{.Status}}  (started by hand)' | sed 's/^/  /'
        echo "images:"
        docker images "$APP" --format '{{.Tag}}  {{.Size}}  {{.CreatedSince}}' | sort -r | sed 's/^/  /' 
        ;;
esac
REMOTE
}

# Waits until the public address answers with this version.
check_public() {
    say "Checking $CHECK_URL"
    for _ in $(seq 1 30); do
        if curl -fsS -m 5 -o /dev/null "$CHECK_URL/up"; then
            echo "$CHECK_URL/up answers"
            return 0
        fi
        sleep 2
    done
    fail "$CHECK_URL/up does not answer. The container is up on the server: look at Traefik."
}

deploy() {
    command -v docker >/dev/null || fail "Docker is not installed here"
    [ -z "$(git status --porcelain)" ] || fail "there are changes that are not committed: a deploy is always of a commit"

    # Sorts by time, and says which commit it is.
    local version
    version="$(date -u +%Y%m%d-%H%M)-$(git rev-parse --short HEAD)"

    say "Building $APP:$version"
    docker build --platform linux/amd64 -t "$APP:$version" .

    say "Sending the image to $SERVER"
    docker save "$APP:$version" | gzip | ssh -o BatchMode=yes "$SERVER" 'gunzip | docker load' | tail -n 1

    say "Starting the new version, then removing the old one"
    remote switch "$version" || fail "the new version did not start; the old one is still serving"

    check_public
    say "Deployed $version"
}

rollback() {
    local current previous
    current="$(remote current)"
    previous="$(remote versions | grep -v -x "$current" | head -n 1 || true)"
    [ -n "$previous" ] || fail "there is no earlier version on the server"

    say "Going back from ${current:-nothing} to $previous"
    remote switch "$previous" || fail "the earlier version did not start; the current one is still serving"
    check_public
    say "Now running $previous"
}

case "${1:-deploy}" in
    deploy) deploy ;;
    status) remote status ;;
    rollback) rollback ;;
    -h | --help | help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) fail "unknown command: $1 (try ./deploy.sh --help)" ;;
esac
