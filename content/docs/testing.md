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

## What a new project checks

- **The conventions.** The same report as `spider check`: routes in the right file, templates using the project's classes.
- **The route table of each feature.** `spider g feature` writes it next to the routes.
- **The app answers.** One request to the running app, described below.
- **That no test file is left out.** A file with tests that nothing imports fails the build, with its name.

The route table is a list of method, path and who may call the route, as `spider routes` prints it:

```zig
const spider = @import("spider");
const routes = @import("routes.zig");

test "posts routes: method, path and access" {
    try spider.testing.expectRoutes(routes.build(), &.{
        .{ "GET", "/posts", "-" },
        .{ "GET", "/posts/new", "-" },
        .{ "GET", "/posts/:id/edit", "-" },
        .{ "POST", "/posts/create", "-" },
        .{ "POST", "/posts/:id/update", "-" },
        .{ "POST", "/posts/:id/delete", "-" },
    });
}
```

Add a route, or change who may call one, and the test fails until the table says the same. It prints the table as it is now, ready to paste.

## Requests against the app

A new project also has `src/app_test.zig`, with a first test that asks the app for its home page:

```zig
const std = @import("std");
const spider = @import("spider");
const core = @import("core");
const db = spider.sqlite;
const main = @import("main.zig");

/// What main() does to serve, on a database of its own: the tests never touch
/// db.sqlite. The migrations run on it, so every table is there.
fn run() !void {
    const gpa = std.heap.smp_allocator;
    var threaded: std.Io.Threaded = .init(gpa, .{});
    const io = threaded.io();

    const path = ".zig-cache/test.sqlite";
    std.Io.Dir.cwd().deleteFile(io, path) catch {};
    try db.init(gpa, io, .{ .path = path });
    try core.db.migrations.migrate(gpa);

    try main.serve(gpa, io);
}

test "the home page answers" {
    const app = try spider.testing.start(run);

    var res = try app.get("/");
    defer res.deinit();
    try res.expectStatus(200);
}
```

`spider.testing.start` runs the real server inside the test, on a free port, and gives you something to send requests with. Nothing is faked: middlewares, templates, the error handler and the database all take part.

`run` is what the server needs to start. It does what `main` does, with one difference: the database is a file of its own, so the tests never touch `db.sqlite`. `main.serve` is the function in `src/main.zig` that builds the server and listens.

`start` runs the server once for all the tests of the project. Every test calls it and gets the same one.

Write your tests below the first one.

## Forms and redirects

`postForm` sends a struct as a form. A redirect is not followed: the response is the redirect itself, and you ask for the next page.

```zig
test "a new post shows up in the list" {
    const app = try spider.testing.start(run);

    var saved = try app.postForm("/posts/create", .{ .name = "Written by a test" });
    defer saved.deinit();
    try saved.expectRedirect("/posts");

    var list = try app.get("/posts");
    defer list.deinit();
    try list.expectContains("Written by a test");
}
```

The tests share one database, and they run in any order. Make each test create what it needs, and do not count on a table being empty.

## Headers, JSON and errors

`request` takes the method, header lines and a body. `postJson` sends JSON.

```zig
test "htmx gets the list without the page around it" {
    const app = try spider.testing.start(run);

    var res = try app.request(.{ .target = "/posts", .headers = &.{"HX-Request: true"} });
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectNotContains("<html");
}

test "an address that does not exist answers 404" {
    const app = try spider.testing.start(run);

    var res = try app.get("/nowhere");
    defer res.deinit();
    try res.expectStatus(404);
}
```

## What a response has

- `res.status`, `res.body`
- `res.header("Location")` and `res.cookie("session")`: the value, or null
- `expectStatus`, `expectContains`, `expectNotContains`, `expectHeader`, `expectRedirect`

A failed expectation prints the request and the start of the body, so you see what the server answered.
