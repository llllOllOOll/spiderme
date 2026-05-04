-- doc

# Quick Start

Spider is a web framework for Zig. This guide gets you from zero to a running HTTP server in under 5 minutes.

## Prerequisites

You need Zig `0.17.0-dev` or later. Download it at [ziglang.org/download](https://ziglang.org/download/).

## Create a new project

```bash
mkdir myapp && cd myapp
zig init
```

## Fetch Spider

```bash
zig fetch --save git+https://github.com/llllOllOOll/spider
```

## Configure build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spider_dep = b.dependency("spider", .{
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "spider", .module = spider_dep.module("spider") },
            },
        }),
    });

    // Auto-generate embedded templates (required for embed mode)
    const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
    gen.addArg("src/");
    gen.addArg("src/embedded_templates.zig");
    exe.step.dependOn(&gen.step);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
}
```

## Write your first handler

```zig
const std = @import("std");
const spider = @import("spider");

pub fn main() void {
    var server = spider.app();
    defer server.deinit();

    server
        .get("/", homeHandler)
        .listen(3000) catch {};
}

fn homeHandler(c: *spider.Ctx) !spider.Response {
    return c.text("Hello, Spider!", .{});
}
```

## Run

```bash
zig build run
```

```
Speed server starting on port 3000...
Server listening on http://127.0.0.1:3000
Starting 12 worker threads
```

Test it:

```bash
curl http://localhost:3000/  # response
```

## Quick template example

Create `src/index.html`:

```html
extends "layout"

<h1>Hello, { name }!</h1>
<p>Today is { date }.</p>
```

Create `src/layout.html`:

```html
<!DOCTYPE html>
<html>
<head><title>{ title ?? "Spider" }</title></head>
<body>
  <main>{ slot }</main>
</body>
</html>
```

Update your handler to use `c.view()` and declare `spider_templates`:

```zig
const spider = @import("spider");
const templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub const spider_templates = templates;

pub fn main() void {
    var server = spider.app();
    defer server.deinit();

    server
        .get("/", home)
        .listen(3000) catch {};
}

fn home(c: *spider.Ctx) !spider.Response {
    return c.view("index", .{
        .title = "Home",
        .name = "Seven",
        .date = "2026-05-04",
    }, .{});
}
```

`{ variable }` interpolates values, `{ slot }` injects child content into the layout, and `{ title ?? "Spider" }` provides a fallback default.

## Next Steps

- [Router](/docs/router) — dynamic params, wildcards, chained routes
- [Templates](/docs/templates) — server-side rendering with components
- [PostgreSQL](/docs/postgresql) — built-in PG client
