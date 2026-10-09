# Posts

A small microblog built with [Spider](https://github.com/llllOllOOll/spider).
It is the example the Spider documentation points to: every feature here is
one the docs explain.

What it does: a feed of posts with the newest first, search by title and
body (`/posts?q=router`), a page for each post with the body rendered from
Markdown, a form to write and edit a post, a confirmation page before a
post is deleted, and a 404 page. The name typed in the form is remembered
in a cookie. Nothing in it needs JavaScript.

## Run it

You need Zig 0.17.0 and the `spider` command line tool.

```bash
spider install   # once: downloads Tailwind and the icons into bin/
spider migrate   # once: creates db.sqlite with the table and four posts
spider dev       # builds, runs, and reloads the browser as you edit
```

Then open http://localhost:3000. Port in use? `spider dev --port 4000`.

## Test it

```bash
zig build test
```

It runs the unit tests, checks the route table and the project conventions,
and calls every route of the app: `src/app_test.zig` starts the real server
on a free port, with a scratch database, and sends it requests.

## Layout

```
src/main.zig                    starts the server, mounts the features, 404 page
src/app_test.zig                one test per route, against the running app
src/features/posts/
  routes.zig                    the routes, in one group under /posts
  controller.zig                one function per route
  model.zig                     Post, the form input and its validation
  repository.zig                the SQL
  present.zig                   initials, "2 hours ago", the excerpt
  views/                        index, show, form, delete, and the PostCard component
src/shared/templates/           layout, the back link, the 404 page
src/core/db/migrations/         the posts table and the first four posts
src/ui.css                      the look: every ui-* class the templates use
public/fonts/                   the fonts, served by the app, with their licenses
Dockerfile                      builds the app with the official Zig, runs it in a small image
```

## How it was made

```bash
spider new posts
cd posts
spider g feature posts
spider ui use tailwind
```

The rest was written on top of what those commands generated.

## In a container

```bash
docker build -t posts .
docker run -p 3000:3000 posts
```
