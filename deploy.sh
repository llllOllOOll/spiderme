#!/usr/bin/env bash
# Deploys the site, or one of the example apps, to the server.
#
#     ./deploy.sh [site|posts|bookings]            build, send, start the new version, retire the old one
#     ./deploy.sh [site|posts|bookings] status     what is running on the server
#     ./deploy.sh [site|posts|bookings] rollback   go back to the version before the current one
#     ./deploy.sh bookings database                once, before its first deploy: its database
#
# Without a name it is the site: spiderme.org. `posts` and `bookings` are
# the example apps of examples/: posts.spiderme.org, bookings.spiderme.org.
#
# How it works. The image is built here and sent to the server over SSH
# (no registry in between). On the server, a Traefik that is already there
# routes by the labels of each container. The new version starts next to
# the old one; when it answers /up, the old one is removed. If it never
# answers, it is removed instead and the old one keeps serving.
#
# It needs: Docker here, and SSH access to the server as a user that can
# run `docker` there. Nothing secret is in this file or in the images: what
# an app needs to keep secret is made on the server the first time, in a
# file only that user can read, and stays there.
set -euo pipefail
cd "$(dirname "$0")"

# ── settings ────────────────────────────────────────────────────────────
SERVER="${DEPLOY_SERVER:-seven@spiderme.org}"
NETWORK="network_public"                 # the Docker network Traefik watches
CERT_RESOLVER="letsencrypt"              # the name of Traefik's certificate resolver
KEEP_IMAGES=3                            # versions kept on the server for rollback

# One block per app.
#   APP      image name and container prefix
#   ROUTE    the name of the Traefik router and service. Two containers may
#            share one only if their labels are identical, and during a
#            deploy the old and the new version run side by side: CHANGE IT
#            WHENEVER YOU CHANGE THE LABELS in start() (v2, v3, ...), or
#            Traefik drops the route while both run.
#   RULE     which addresses reach the app
#   CONTEXT  the directory with its Dockerfile
#   VOLUME   "name:/path" kept across versions, or empty
#   SETTINGS "KEY=value ..." given to the container as they are (not secret)
#   SECRETS  names of variables the server makes up once (random) and keeps
#   LEGACY   a container started by hand before this script existed
#   DATABASE "container:name" for an app on PostgreSQL: the PostgreSQL
#            container that is already on the server, and the name of the
#            app's own database and role in it (see `database` below)
TARGET="site"
case "${1:-}" in site | posts | bookings)
    TARGET="$1"
    shift
    ;;
esac

case "$TARGET" in
    site)
        APP="spiderme-site"
        ROUTE="spiderme-site-v2"
        RULE='Host(`spiderme.org`) || Host(`www.spiderme.org`)'
        CONTEXT="."
        CHECK_URL="https://spiderme.org"
        VOLUME=""
        SETTINGS=""
        SECRETS=""
        LEGACY="spiderme-app"
        DATABASE=""
        ;;
    posts)
        APP="spiderme-posts"
        ROUTE="spiderme-posts-v1"
        RULE='Host(`posts.spiderme.org`)'
        CONTEXT="examples/posts"
        CHECK_URL="https://posts.spiderme.org"
        VOLUME="spiderme-posts-data:/data" # the SQLite file
        SETTINGS="SQLITE_PATH=/data/db.sqlite"
        SECRETS="JWT_SECRET POSTS_API_KEY" # sessions; the key of the JSON API
        LEGACY=""
        DATABASE=""
        ;;
    bookings)
        APP="spiderme-bookings"
        ROUTE="spiderme-bookings-v1"
        RULE='Host(`bookings.spiderme.org`)'
        CONTEXT="examples/bookings"
        CHECK_URL="https://bookings.spiderme.org"
        VOLUME=""
        SETTINGS="PG_HOST=postgres-main PG_PORT=5432 PG_USER=bookings PG_DB=bookings BOOKINGS_URL=https://bookings.spiderme.org"
        SECRETS="JWT_SECRET PG_PASSWORD" # sessions; the password of its database role
        LEGACY=""
        DATABASE="postgres-main:bookings"
        ;;
esac

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
fail() {
    printf '\033[31merror: %s\033[0m\n' "$*" >&2
    exit 1
}

# Runs the functions below on the server. They only touch containers,
# images and the volume of this app.
remote() {
    # shellcheck disable=SC2029
    ssh -o BatchMode=yes "$SERVER" "APP='$APP' ROUTE='$ROUTE' NETWORK='$NETWORK' CERT_RESOLVER='$CERT_RESOLVER' KEEP_IMAGES='$KEEP_IMAGES' LEGACY='$LEGACY' RULE='$RULE' VOLUME='$VOLUME' SETTINGS='$SETTINGS' SECRETS='$SECRETS' DATABASE='$DATABASE' bash -s -- $*" <<'REMOTE'
set -euo pipefail

# The containers of this app.
containers() { docker ps -a --filter "label=deploy.app=$APP" --format '{{.Names}}' ; }

# The file with the app's secrets: made the first time, one random value
# per name, readable by this user only. Never printed.
secrets_file() {
    [ -n "$SECRETS" ] || return 0
    local file="$HOME/.config/spiderme-deploy/$APP.env"
    mkdir -p "$(dirname "$file")"
    chmod 700 "$(dirname "$file")"
    touch "$file"
    chmod 600 "$file"
    for name in $SECRETS; do
        grep -q "^$name=" "$file" || printf '%s=%s\n' "$name" "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')" >> "$file"
    done
    echo "$file"
}

start() {
    local version="$1" name="$APP-$1"
    local extra=()
    [ -z "$VOLUME" ] || extra+=(--volume "$VOLUME")
    for setting in $SETTINGS; do extra+=(--env "$setting"); done
    local file
    file="$(secrets_file)"
    [ -z "$file" ] || extra+=(--env-file "$file")

    docker rm -f "$name" >/dev/null 2>&1 || true
    docker run -d \
        --name "$name" \
        --restart unless-stopped \
        --network "$NETWORK" \
        ${extra[@]+"${extra[@]}"} \
        --label "deploy.app=$APP" \
        --label "deploy.version=$version" \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.$ROUTE.rule=$RULE" \
        --label "traefik.http.routers.$ROUTE.entrypoints=websecure" \
        --label "traefik.http.routers.$ROUTE.tls=true" \
        --label "traefik.http.routers.$ROUTE.tls.certresolver=$CERT_RESOLVER" \
        --label "traefik.http.routers.$ROUTE.middlewares=$ROUTE-retry" \
        --label "traefik.http.middlewares.$ROUTE-retry.retry.attempts=3" \
        --label "traefik.http.middlewares.$ROUTE-retry.retry.initialinterval=100ms" \
        --label "traefik.http.services.$ROUTE.loadbalancer.server.port=3000" \
        --label "traefik.http.services.$ROUTE.loadbalancer.healthcheck.path=/up" \
        --label "traefik.http.services.$ROUTE.loadbalancer.healthcheck.interval=5s" \
        --label "traefik.http.services.$ROUTE.loadbalancer.healthcheck.timeout=3s" \
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

# Removes every container of the app except the one of `version`. A request
# that was on its way to one of them is sent again by Traefik to the new
# one (the retry label above).
retire_others() {
    local keep="$APP-$1"
    for name in $(containers) $LEGACY; do
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
    database)
        # The app's own role and database, made once. The password is the
        # one in the app's file on this server: it is read here and goes to
        # psql on its input, so it is never printed nor in a command line.
        # Running it again changes nothing but sets the same password.
        [ -n "$DATABASE" ] || { echo "$APP has no database" >&2; exit 1; }
        container="${DATABASE%%:*}" name="${DATABASE##*:}"
        password="$(grep '^PG_PASSWORD=' "$(secrets_file)" | cut -d= -f2-)"
        [ -n "$password" ] || { echo "no PG_PASSWORD in the app's file" >&2; exit 1; }
        docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -q -d postgres <<SQL
DO \$\$ BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = '$name') THEN
        ALTER ROLE "$name" LOGIN PASSWORD '$password';
    ELSE
        CREATE ROLE "$name" LOGIN PASSWORD '$password';
    END IF;
END \$\$;
SELECT 'CREATE DATABASE "$name" OWNER "$name"' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$name') \gexec
REVOKE CONNECT ON DATABASE "$name" FROM PUBLIC;
SQL
        echo "database $name and role $name are in $container"
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
        [ -z "$LEGACY" ] || docker ps -a --filter "name=^${LEGACY}$" --format '{{.Names}}  {{.Status}}  (started by hand)' | sed 's/^/  /'
        echo "images:"
        docker images "$APP" --format '{{.Tag}}  {{.Size}}  {{.CreatedSince}}' | sort -r | sed 's/^/  /'
        if [ -n "$VOLUME" ]; then
            echo "volume:"
            docker volume ls --filter "name=^${VOLUME%%:*}$" --format '{{.Name}}' | sed 's/^/  /'
        fi
        ;;
esac
REMOTE
}

# Waits until the public address answers.
check_public() {
    say "Checking $CHECK_URL"
    for _ in $(seq 1 45); do
        if curl -fsS -m 5 -o /dev/null "$CHECK_URL/up" 2>/dev/null; then
            echo "$CHECK_URL/up answers"
            return 0
        fi
        sleep 2
    done
    fail "$CHECK_URL/up does not answer. The container is up on the server: look at Traefik (a new address waits for its certificate)."
}

deploy() {
    command -v docker >/dev/null || fail "Docker is not installed here"
    [ -z "$(git status --porcelain)" ] || fail "there are changes that are not committed: a deploy is always of a commit"

    # Sorts by time, and says which commit it is.
    local version
    version="$(date -u +%Y%m%d-%H%M)-$(git rev-parse --short HEAD)"

    say "Building $APP:$version"
    docker build --platform linux/amd64 -t "$APP:$version" "$CONTEXT"

    say "Sending the image to $SERVER"
    docker save "$APP:$version" | gzip | ssh -o BatchMode=yes "$SERVER" 'gunzip | docker load' | tail -n 1

    say "Starting the new version, then removing the old one"
    remote switch "$version" || fail "the new version did not start; the old one is still serving"

    check_public
    say "Deployed $APP $version"
}

rollback() {
    local current previous
    current="$(remote current)"
    previous="$(remote versions | grep -v -x "$current" | head -n 1 || true)"
    [ -n "$previous" ] || fail "there is no earlier version on the server"

    say "Going back from ${current:-nothing} to $previous"
    remote switch "$previous" || fail "the earlier version did not start; the current one is still serving"
    check_public
    say "Now running $APP $previous"
}

case "${1:-deploy}" in
    deploy) deploy ;;
    status) remote status ;;
    rollback) rollback ;;
    database) remote database ;;
    -h | --help | help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) fail "unknown command: $1 (try ./deploy.sh --help)" ;;
esac
