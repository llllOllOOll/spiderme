-- doc

# Quick Start

Spider is a web framework for Zig. This guide gets you from zero to a running HTTP server in under 5 minutes.

## Prerequisites

- **Zig 0.17.0-dev** or later — [ziglang.org/download](https://ziglang.org/download/)
- **Docker** — for PostgreSQL (optional, needed for database features)
- **curl** — for CLI install (optional, only for Flow A)

---

There are two ways to start a Spider project:

- **Flow A — CLI (recommended):** Install via `curl` and use `spider new` to scaffold
- **Flow B — Manual:** Add Spider as a dependency with `zig fetch`

Both produce the same result. Choose the one that fits your workflow.

---

## Flow A — CLI Install

### 1. Install Spider CLI

```bash
curl -fsSL https://spiderme.org/install.sh | bash
```

This installs the `spider` command to `~/.local/bin/spider`. Verify it works:

```bash
spider help
```

### 2. Create a project

```bash
spider new myapp
cd myapp
```

This generates a complete project with:

- `build.zig` + `build.zig.zon` — build configuration
- `spider.config.zig` — runtime configuration
- `src/main.zig` — entry point with route setup
- `src/shared/templates/` — layout, nav, sidebar, toast components
- `src/features/home/` — sample controller + view
- `Dockerfile` + `docker-compose.yml` — PostgreSQL and deployment
- `.env.example` — environment variables template
- `public/` — static assets (CSS, JS, images)
- `bin/` — Tailwind CSS CLI (auto-downloaded)

### 3. Setup environment

```bash
cp .env.example .env
docker compose up -d   # starts PostgreSQL
```

### 4. Generate a feature (optional)

```bash
spider g feature todo
```

This creates `src/features/todo/` with controller, view, and module registration.

### 5. Run

```bash
zig build run
```

```
Spider server starting on port 3000...
Server listening on http://127.0.0.1:3000
Starting 12 worker threads
```

Visit [http://localhost:3000](http://localhost:3000).

---

## Flow B — Manual Setup

### 1. Start a Zig project

```bash
mkdir myapp && cd myapp
zig init
```

### 2. Add Spider dependency

```bash
zig fetch --save git+https://github.com/llllOllOOll/spider
```

### 3. Configure build.zig

Replace `build.zig` with:

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

### 4. Create entry point

`src/main.zig`:

```zig
const std = @import("std");
const spider = @import("spider");

pub fn main() void {
    var server = spider.app();
    defer server.deinit();

    server
        .get("/", homeHandler)
        .listen(.{ .port = 3000 }) catch {};
}

fn homeHandler(c: *spider.Ctx) !spider.Response {
    return c.text("Hello, Spider!", .{});
}
```

### 5. Setup config and database

Create `spider.config.zig`:

```zig
const spider = @import("spider");

pub const config = spider.Config{
    .port = 3000,
    .env = .development,
};
```

Create `docker-compose.yml`:

```yaml
services:
  pg:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: spider
      POSTGRES_PASSWORD: spider
      POSTGRES_DB: myapp
    ports:
      - "5432:5432"
```

Create `.env`:

```
PG_HOST=localhost
PG_PORT=5432
PG_USER=spider
PG_PASSWORD=spider
PG_DB=myapp
```

### 6. Start database

```bash
docker compose up -d
```

### 7. Run

```bash
zig build run
```

```
Spider server starting on port 3000...
Server listening on http://127.0.0.1:3000
Starting 12 worker threads
```

---

## What's next

Both flows produce a running Spider app. From here you can:

### Templates

Create `src/index.html`:

```html
extends "layout"

<h1>Hello, { name }!</h1>
<p>Today is { date }.</p>
```

Update `src/main.zig` to use `c.view()`:

```zig
const templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub const spider_templates = templates;

fn home(c: *spider.Ctx) !spider.Response {
    return c.view("index", .{
        .title = "Home",
        .name = "Seven",
        .date = "2026-05-04",
    }, .{});
}
```

### Generate features

```bash
spider g feature products
```

### Run migrations

```bash
spider migrate
```

### Listen options

```zig
.listen(.{ .port = 3000 })                    // override port only
.listen(.{ .host = "0.0.0.0" })               // override host only
.listen(.{ .port = 3000, .host = "0.0.0.0" }) // override both
.listen(.{})                                   // use config values
```

---

## Next Steps

- [Router](/docs/router) — dynamic params, wildcards, chained routes
- [Templates](/docs/templates) — server-side rendering with components
- [PostgreSQL](/docs/postgresql) — built-in PG client
- [CLI](/docs/cli) — spider new, generate, migrate commands
