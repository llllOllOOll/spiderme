#!/usr/bin/env bash
# Calls every route of the app once, against a running copy of it with its
# own scratch database. Run it from anywhere:
#
#     zig build && test/routes.sh
#
# It needs the `spider` CLI (to apply the migrations) and curl.
set -euo pipefail
cd "$(dirname "$0")/.."

port="${PORT:-39461}"
base="http://127.0.0.1:$port"
work="$(mktemp -d)"
app=""
cleanup() {
    [ -n "$app" ] && kill "$app" 2>/dev/null
    rm -r -- "$work"
}
trap cleanup EXIT

# `spider migrate` reads the database path from the .env of the project it
# runs in, so the scratch database gets a stand-in project of its own.
ln -s "$PWD/src" "$work/src"
touch "$work/build.zig.zon"
echo "SQLITE_PATH=$work/test.sqlite" > "$work/.env"
(cd "$work" && spider migrate > "$work/migrate.log" 2>&1) || { cat "$work/migrate.log"; exit 1; }

# SPIDER_DEV_PORT is the port `spider dev --port` gives a debug build.
SQLITE_PATH="$work/test.sqlite" SPIDER_DEV_PORT="$port" ./zig-out/bin/posts > "$work/app.log" 2>&1 &
app=$!
for _ in $(seq 1 50); do
    curl -s -o /dev/null "$base/posts" && break
    sleep 0.1
done

failed=0
pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; failed=1; }

# check <name> <expected status> <text the page must contain> <curl arguments...>
check() {
    local name="$1" status="$2" text="$3"
    shift 3
    local got
    got="$(curl -s -o "$work/body" -w '%{http_code}' "$@")"
    if [ "$got" != "$status" ]; then
        fail "$name: status $got, expected $status"
    elif [ -n "$text" ] && ! grep -qF -- "$text" "$work/body"; then
        fail "$name: the page does not contain: $text"
    else
        pass "$name"
    fi
}

# header <name> <header line the answer must contain> <curl arguments...>
header() {
    local name="$1" line="$2"
    shift 2
    if curl -s -o /dev/null -D - "$@" | tr -d '\r' | grep -qiF -- "$line"; then
        pass "$name"
    else
        fail "$name: no header: $line"
    fi
}

form=(--data-urlencode "title=Hello from the test" --data-urlencode "body=A **bold** start." --data-urlencode "author=Test Writer")

header "GET /                    goes to the feed"       "location: /posts"             "$base/"
check  "GET /posts               lists the seed posts"   200 "Routes that read like a sentence" "$base/posts"
check  "GET /posts               newest first"           200 "2 hours ago"              "$base/posts"
check  "GET /posts?q=            finds a title"          200 "Running Spider in a tiny container" "$base/posts?q=container"
check  "GET /posts?q=            finds a body"           200 "My first week with Zig 0.17" "$base/posts?q=allocators"
check  "GET /posts?q=            says when nothing matches" 200 "No post mentions" "$base/posts?q=nothing-like-this"
check  "GET /posts/:id           shows a post"           200 "<h2>What I deleted</h2>"  "$base/posts/4"
check  "GET /posts/:id           404 for a missing post" 404 "This page is not here"    "$base/posts/9999"
check  "GET /posts/:id           404 for a bad id"       404 "This page is not here"    "$base/posts/abc"
check  "GET /posts/new           shows the form"         200 "Publish post"             "$base/posts/new"
check  "GET /posts/new           remembers the author"   200 'value="Ana Ribeiro"'      -H "Cookie: author=Ana%20Ribeiro" "$base/posts/new"
check  "POST /posts/create       rejects empty fields"   422 "Give the post a title."   -X POST --data-urlencode "title= " --data-urlencode "body=x" --data-urlencode "author=x" "$base/posts/create"
header "POST /posts/create       saves and goes to the post" "location: /posts/5"       -X POST "${form[@]}" "$base/posts/create"
header "POST /posts/create       sets the author cookie" "set-cookie: author=Test%20Writer" -X POST "${form[@]}" "$base/posts/create"
check  "GET /posts/:id           renders the new post"   200 "A <b>bold</b> start."     "$base/posts/5"
check  "GET /posts/:id/edit      shows the saved values" 200 'value="Hello from the test"' "$base/posts/5/edit"
check  "GET /posts/:id/edit      404 for a missing post" 404 ""                         "$base/posts/9999/edit"
check  "POST /posts/:id/update   rejects empty fields"   422 "Write something in the body." -X POST --data-urlencode "title=x" --data-urlencode "body=" --data-urlencode "author=x" "$base/posts/5/update"
header "POST /posts/:id/update   saves and goes to the post" "location: /posts/5"       -X POST --data-urlencode "title=Edited title" --data-urlencode "body=Edited" --data-urlencode "author=Test Writer" "$base/posts/5/update"
check  "GET /posts/:id           shows the edit"         200 "Edited title"             "$base/posts/5"
check  "POST /posts/:id/update   404 for a missing post" 404 ""                         -X POST "${form[@]}" "$base/posts/9999/update"
check  "GET /posts/:id/delete    asks first"             200 "Delete this post?"        "$base/posts/5/delete"
header "POST /posts/:id/delete   deletes and goes to the feed" "location: /posts"       -X POST "$base/posts/5/delete"
check  "GET /posts/:id           is gone after the delete" 404 ""                       "$base/posts/5"
check  "POST /posts/:id/delete   404 for a missing post" 404 ""                         -X POST "$base/posts/9999/delete"
check  "GET /nowhere             404 page"               404 "This page is not here"    "$base/nowhere"

exit "$failed"
