---
title: The build
section: guide
order: 265
---

# The build

Spider has a lot in it, and an app gets only what it asks for. A database driver, file storage, QR codes, spreadsheets: each is a library the project adds when it needs it, with one line. What a project did not ask for is not compiled and is not in its binary.

Two files at the root of the project say what it asked for. `build.zig.zon` names Spider and the exact version in use. `build.zig` says which optional parts are on, where templates come from and how the app is compiled. `spider new` writes both. This page is what to know before changing them.

The code is from `examples/build` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/build)): one small app that its own tests build in more than one way. Everything here, the sizes included, was run on Spider 0.10.1.

## build.zig.zon: which Spider

```zig from=examples/build/build.zig.zon
```

- `.url` is the release: a tag, and the commit it stood for when it was fetched.
- `.hash` is the checksum of what was downloaded. Zig refuses a package that does not match it, so every machine builds the same Spider.

The first `zig build` downloads Spider into `zig-pkg/`, inside the project and out of git. After that a build needs no network.

`spider update` moves the project to the latest release by rewriting those two lines ([Command line tool](/docs/cli)). To choose the release yourself:

```bash
zig fetch --save=spider "git+https://github.com/llllOllOOll/spider?ref=v0.10.1"
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
- `.templates`: `.auto`, `.embedded` or `.disk`. See [below](#Templates-in-the-binary-or-on-disk).
- `.io_backend`: `.threaded` or `.zio`. See [below](#The-I-O-backend).
- `.optimize` and `.target`: pass the app's own, as above. Without `.optimize`, Spider stays in Debug inside a release build.

`spider new` writes `.sqlite = true`, `spider new --pg` writes `.pg = true`, and `--no-db` writes neither.

## Optional parts

Think of the five parts above as libraries that ship with Spider: SQLite, PostgreSQL, file storage, QR codes, spreadsheets. None of them is on by default. A project turns on the ones it needs and leaves the rest out.

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

- Asking costs nothing until the code uses the part. A new project built with all five asked for and none used gives the same binary, to the byte, as one that asked for none.
- A part that is used adds only itself. Making a QR code in that project added about 7 KB to a release build of 366 KB.
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

`generate-templates` is a small program that comes with Spider. The build compiles it and runs it before the app, every time. It walks `src/`, finds every `.html` and `.md` file, and writes `src/embedded_templates.zig`: a list with one line per file. For the example's one template the whole list is:

```zig
hello_index: []const u8 = @embedFile("features/hello/views/index.html"),
```

- The file is a list, not a copy: each line points at a template. Whether the templates then go into the binary is the choice below.
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

`zig build` makes a Debug build: quick to compile, with every safety check, templates on disk, and large. `zig build -Doptimize=ReleaseSmall` makes the one to deploy:

```bash
zig build -Doptimize=ReleaseSmall
```

A new project with no database is about 25 MB in Debug and 366 KB in ReleaseSmall, on Linux x86_64. `ReleaseSafe` keeps the safety checks and `ReleaseFast` favours speed; both embed the templates too, and are between 6 and 7 MB. The [Dockerfile](/docs/docker) of a new project uses `ReleaseSmall`.

## The I/O backend

`.io_backend` chooses how the server waits on sockets:

- `.threaded`, the default: operating system threads and blocking sockets.
- `.zio`: fibers on an event loop. It is the newer of the two and still marked experimental in Spider's build.

The app's code is the same for both. A new project's `build.zig` has the two lines, one commented out.

## What else build.zig does

The `build.zig` of a new project also:

- gives `spider.config.zig` to Spider ([Configuration](/docs/configuration));
- compiles the stylesheet with Tailwind as part of every build, and alone with `zig build css`;
- has `zig build run`, `zig build test` ([Testing](/docs/testing)) and the `dev` step that `spider dev` runs ([Development](/docs/development)).
