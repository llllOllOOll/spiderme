---
title: The build
section: guide
order: 265
---

# The build

Spider has a lot in it, and an app gets only what it asks for. A database driver, file storage, QR codes, spreadsheets: each is a library the project adds when it needs it, with one line. What a project did not ask for is not compiled and is not in its binary.

Two files at the root of the project say what it asked for. `build.zig.zon` names Spider and the exact version in use. `build.zig` says which optional parts are on, where templates come from and how the app is compiled. `spider new` writes both. This page is what to know before changing them.

The code is from `examples/build` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/build)): one small app that its own tests build in more than one way. Everything here, the sizes included, was run on Spider 0.14.0-dev.

## build.zig.zon: which Spider

```zig from=examples/build/build.zig.zon
```

- `.url` is where Spider comes from and the exact commit: a release tag (`?ref=v0.12.1`), or, as here, the `develop` branch at the commit it stood at when it was fetched. [Versions](/docs/versions) says which to choose.
- `.hash` is the checksum of what was downloaded. Zig refuses a package that does not match it, so every machine builds the same Spider.

The first `zig build` downloads Spider into `zig-pkg/`, inside the project and out of git. After that a build needs no network.

`spider update` moves the project by rewriting those two lines: to the latest release, to a release you name, or with `--canary` to the `develop` branch ([Command line tool](/docs/cli)). By hand:

```bash
zig fetch --save=spider "git+https://github.com/llllOllOOll/spider?ref=v0.12.1"   # a release
zig fetch --save=spider "git+https://github.com/llllOllOOll/spider#develop"      # develop, at today's commit
```

## build.zig: what the project asks for

Spider is declared once, with what this project wants of it. A new project has the same call inside its `build` function:

```zig from=examples/build/build.zig decl=spider
```

Everything a project can ask for:

- `.sqlite = true`: `spider.sqlite`, and SQLite itself, compiled into the app ([Database](/docs/database)).
- `.pg = true`: `spider.pg` ([PostgreSQL](/docs/postgres)).
- `.r2 = true`: `spider.r2` ([File storage](/docs/storage)).
- `.qrcode = true`: `spider.qrcode` ([QR codes](/docs/qrcode)).
- `.xlsx = true`: `spider.xlsx` ([Spreadsheets](/docs/spreadsheets)).
- `.mssql = true`: `spider.mssql` ([SQL Server](/docs/sqlserver)).
- `.templates`: `.auto`, `.embedded` or `.disk`. See [below](#Templates-in-the-binary-or-on-disk).
- `.io_backend`: `.zio` (the default) or `.threaded`. See [below](#The-I-O-backend).
- `.optimize` and `.target`: pass the app's own, as above. Without `.optimize`, Spider stays in Debug inside a release build.

`spider new` writes `.sqlite = true`, `spider new --pg` writes `.pg = true`, and `--no-db` writes neither.

## Optional parts

Think of the six parts above as libraries that ship with Spider: SQLite, PostgreSQL, SQL Server, file storage, QR codes, spreadsheets. None of them is on by default. A project turns on the ones it needs and leaves the rest out.

What every app has without asking is the web framework itself: routing, templates, forms, live pages, WebSocket, login, mail, push, jobs, the HTTP client. Even there, only the code the app reaches is compiled into it.

A part that was not asked for is not compiled and is not in the binary. Code that uses it does not compile:

```zig from=examples/build/src/sheet.zig
```

```text
error: no module named 'spider_xlsx' available within module 'spider'
```

The error names the part, and the fix is its line in `build.zig`. A part that was asked for is simply there:

```zig from=examples/build/src/ticket.zig
```

Good to know:

- Asking costs nothing until the code uses the part, with one exception. A new project built with SQLite, SQL Server, file storage, QR codes and spreadsheets asked for and none used gives the same binary, to the byte, as one that asked for none. PostgreSQL adds about 3 KB even unused: the code that checks the migrations before the server listens comes with it ([Migrations in production](/docs/migrations)).
- A part that is used adds only itself. Making a QR code in that project added about 8 KB to a ReleaseSmall build of 942 KB.
- There is nothing more to download. The optional parts come inside the Spider package; the line in `build.zig` decides what is compiled, not what is fetched.

## Templates: in the binary or on disk

An app says it has templates to embed with one line in `src/main.zig`:

```zig from=examples/build/src/main.zig decl=spider_templates
```

and `build.zig` writes that file before it compiles the app:

```zig from=examples/build/build.zig decl=embedTemplates
```

`spider new` sets all of this up.

### The program that finds the templates

`generate-templates` is a small program that comes with Spider. The build compiles it and runs it before the app, every time. It walks `src/`, finds every `.html` and `.md` file, and writes `src/embedded_templates.zig`. For the example's one template the file is:

```zig
pub const EmbeddedTemplates = struct {
    hello_index: []const u8 = @embedFile("features/hello/views/index.html"),

    pub const spider_manifest = struct {
        pub const hello_index = .{
            .{ "name", 1, .text, false, "" },
        };
    };

    pub const elroy = struct {
        const std = @import("std");
        const E = @import("spider").elroy;

        pub fn hello_index(w: *std.Io.Writer, data: anytype, alc: std.mem.Allocator) !void {
            _ = alc;
            try w.writeAll(__t1[0..11]);
            try E.interp(w, &data, "name");
            try w.writeAll(__t1[19..25]);
        }
        const __t1 = @embedFile("features/hello/views/index.html");
    };
};
```

- The first line points at the template file. Whether the templates then go into the binary is the choice below.
- `spider_manifest` lists what each template reads (here `name`, on line 1, as text). `c.viewChecked` uses it to check a view's data when the app compiles ([Templates](/docs/templates)).
- `elroy` is the template compiled into a Zig function, which a release build renders with: the text is written straight from the template file, and the data is read field by field. See [Compiled templates](/docs/templates#Compiled-templates).
- It is written again by every build, so it stays out of git and is never edited by hand.
- A template added, renamed or removed is in the list after the next build. Nothing registers templates by hand.
- The name on the left is how the file is found: `features/hello/views/index.html` is the view `"hello/index"`. A file whose name starts with a capital letter is a [component](/docs/components), known by that name alone.

The build of a new project runs two more programs that come with Spider: one lists the files that have tests, so that none is left out of `zig build test` ([Testing](/docs/testing)), and one tells `spider dev` that a new build is ready ([Development](/docs/development)). All three run on your machine during the build. None of them is in the app.

### In the binary or on disk

Where the templates then come from is `.templates` on the Spider dependency:

- `.auto`, the default: read from disk in a Debug build, kept in the binary in a release build.
- `.embedded`: in the binary, in every build.
- `.disk`: read from disk, in every build.

**On disk.** Templates are read on every request from `views_dir` of `spider.config.zig`, a path relative to the directory the app is started in. Save a template and the next request shows it, with no build. The binary alone is not enough: started somewhere else it says so,

```text
[spider] WARNING: views_dir "./src" not found.
```

and a page that needs a template fails with `TemplateNotFound`.

**In the binary.** The files are compiled in. The app runs from any directory and a deploy is the binary and the `public` folder. A template that changed needs a build.

The example builds the same app both ways and runs each from a directory with no templates: the first answers, the second cannot.

Good to know:

- `.auto` follows the `.optimize` given to the Spider dependency, not the app's. Leave `.optimize = optimize` out and Spider is in Debug, so a release build reads its templates from disk.
- An app that reads its templates from disk says so when it starts, with the directory.
- An app with no `spider_templates` in `src/main.zig` has nothing to embed: its templates are always read from disk.
- `.embedded` in a Debug build is for trying the app the way it will be deployed. `.disk` in a release build is for changing templates on the server without a build, and then the template folder is deployed with the binary.

## Debug and release

`zig build` makes a Debug build: quick to compile, with every safety check, templates on disk, and large. A release build is the one to deploy:

```bash
zig build -Doptimize=ReleaseSafe
```

- `ReleaseSafe` keeps the safety checks: an out-of-bounds index or an overflow stops the program with a stack trace instead of going on with bad memory. It is the one to use for a server.
- `ReleaseFast` drops the checks and favours speed; `ReleaseSmall` drops them and favours size. The [Dockerfile](/docs/docker) of a new project uses `ReleaseSmall`.

All three embed the templates and render them compiled.

### The debug info, in a file of its own

The last line of a new project's `build.zig` installs the app:

```zig
@import("spider").installApp(b, exe);
```

In a release build it puts the debug info in a separate file next to the binary, `<app>.debug`, and links the binary to it. The binary that ships keeps the names of its functions, so a crash still prints a stack trace with them; with `<app>.debug` beside it the trace has files and lines too. Keep that file with each version you deploy. `-Ddebug-info=true` keeps the debug info inside the binary instead.

A new project with no database, on Linux x86_64:

| Build | The binary | `<app>.debug` |
|---|---|---|
| Debug | 38 MB | none: it is inside |
| ReleaseSmall | 942 KB | 4.0 MB |
| ReleaseSafe | 1.6 MB | 7.2 MB |
| ReleaseFast | 1.7 MB | 8.0 MB |

The split is for Linux binaries. A Windows build installs `<app>.exe` and `<app>.pdb`, as Zig makes them.

## The I/O backend

`.io_backend` chooses how the server waits on sockets:

- `.zio`, the default: fibers on an event loop. A few threads, about one per core, serve any number of connections; a connection waiting for the network costs a fiber, not a thread. On Linux it uses epoll, on macOS and the BSDs kqueue, on Windows IOCP.
- `.threaded`: one operating system thread per open connection, with blocking sockets. Threads it starts for a wave of connections stay in its pool afterwards, with their memory: a server that once held a thousand connections keeps about a thousand sleeping threads.

The app's code is the same for both, and both are tested on every change to Spider. A new project's `build.zig` has the two lines, one commented out. The measurements behind the default are in Spider's [ADR 0001](https://github.com/llllOllOOll/spider/blob/develop/docs/adr/0001-io-backend.md).

## Platforms

Deploy on Linux: it is where Spider is built, tested and measured. Develop on Linux, macOS or Windows. On Windows, `spider new`, `zig build`, running the app and `zig build test` work; not yet there are connection deadlines (a client that sends nothing keeps its connection open, so do not expose a Windows build to the internet) and `spider dev`.

## What else build.zig does

The `build.zig` of a new project also:

- gives `spider.config.zig` to Spider ([Configuration](/docs/configuration));
- on PostgreSQL, builds the migrations into the binary with `spider.addMigrations` ([Migrations in production](/docs/migrations));
- compiles the stylesheet with Tailwind as part of every build, and alone with `zig build css`;
- has `zig build run`, `zig build test` ([Testing](/docs/testing)) and the `dev` step that `spider dev` runs ([Development](/docs/development)).

A [module](/docs/modules) is one more dependency in `build.zig.zon`, which `build.zig` gives the app's own Spider.
