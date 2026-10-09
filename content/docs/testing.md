---
title: Testing
section: guide
order: 55
---

# Testing

```bash
zig build test
```

It runs every test of the project. A new project has a few already, and this page shows how to add the most useful kind: tests that send requests to the app.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts`.

## What a new project checks

- **The conventions.** The same report as `spider check`: routes in the right file, templates using the project's classes.
- **The route table of each feature.** `spider g feature` writes it next to the routes.
- **The app answers.** One request to the running app, described below.
- **That no test file is left out.** A file with tests that nothing imports fails the build, with its name.

The route table is a list of method, path and who may call the route, as `spider routes` prints it. This is the one of the posts feature:

```zig from=examples/posts/src/features/posts/routes_test.zig decl="posts routes: method, path and access"
```

Add a route, or change who may call one, and the test fails until the table says the same. It prints the table as it is now, ready to paste.

## Requests against the app

A new project also has `src/app_test.zig`, with a function called `run` and a first test. `run` does what `main` does to start the server, with one difference: the database is a file of its own, so the tests never touch `db.sqlite`.

```zig from=examples/posts/src/app_test.zig decl=scratch_db,run
```

`main.serve` is the function in `src/main.zig` that builds the server and listens.

A test asks for the app with `spider.testing.start(run)`. It runs the real server, on a free port, once for all the tests of the project: every test calls it and gets the same one. Nothing is faked: middlewares, templates, the error handler and the database all take part.

```zig from=examples/posts/src/app_test.zig decl="GET /posts lists the posts, newest first"
```

`app.get` sends a request, and what comes back has the status, the headers and the body, with a few checks ready: `expectStatus`, `expectContains`.

The tests share one database, and they run in any order. Make each test create what it needs, and do not count on a table being empty.

## Forms and redirects

`postForm` sends a struct as a form. A redirect is not followed: the response is the redirect itself, and you ask for the next page.

Posts sends a visitor who is not signed in to the sign-in page, whatever they try to write:

```zig from=examples/posts/src/app_test.zig decl="writing needs a login: a visitor is sent to the sign-in page"
```

## A signed-in visitor

To test what needs a login, sign up in the test and keep the cookie. This helper comes with `spider g auth`:

```zig from=examples/posts/src/app_test.zig decl=signUp
```

`app.with` gives the same app sending those headers on every request, so the rest of the test reads like the visitor using the site:

```zig from=examples/posts/src/app_test.zig decl="POST /posts/create saves the post under the name of who is signed in"
```

## Headers and JSON

`request` takes the method, header lines and a body, for everything the shortcuts do not cover. The API of Posts wants a key in a header and a JSON body:

```zig from=examples/posts/src/app_test.zig decl=key decl="POST /api/posts saves a post sent as JSON"
```

## What a response has

- `res.status`, `res.body`
- `res.header("Location")` and `res.cookie("session")`: the value, or null
- `expectStatus`, `expectContains`, `expectNotContains`, `expectHeader`, `expectRedirect`

A failed expectation prints the request and the start of the body, so you see what the server answered.
