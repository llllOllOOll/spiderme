-- doc

# Templates

Spider's template engine renders `.html` and `.md` files server-side via `c.view()`. Templates are embedded at compile time with `@embedFile` — no JavaScript build step, no dependencies.

## How it works

At build time, `generate-templates` scans `src/` and embeds all `.html` and `.md` files into a single Zig struct:

```zig
// src/embedded_templates.zig — auto-generated, do not edit
pub const EmbeddedTemplates = struct {
    index: []const u8 = @embedFile("index.html"),
    layout_docs: []const u8 = @embedFile("layout_docs.html"),
};
```

Spider loads this struct at startup. Templates are resolved by name at request time via `c.view()`.

## Quick Start

**1. Create `src/index.html`:**

```html
<!DOCTYPE html>
<html>
<head><title>Spider App</title></head>
<body>
  <h1>Hello, { name }!</h1>
</body>
</html>
```

**2. Create the handler in `src/main.zig`:**

```zig
const spider = @import("spider");

pub fn index(c: *spider.Ctx) !spider.Response {
    return c.view("index", .{ .name = "Seven" }, .{});
}
```

**3. Register the route:**

```zig
var server = spider.app();
server.get("/", index);
server.listen(.{ .port = 8080 }) catch {};
```

Visit `http://localhost:8080/` — you'll see `Hello, Seven!`.

## Variable interpolation

Use `{ variable }` to render values from your handler context:

```html
<h1>{ title }</h1>
<p>Welcome, { user_name }!</p>
<p>Items in cart: { count }</p>
```

```zig
pub fn page(c: *spider.Ctx) !spider.Response {
    return c.view("page", .{
        .title = "Dashboard",
        .user_name = "Alice",
        .count = "42",
    }, .{});
}
```

Missing variables render as empty string — no errors, no crashes.

## Conditionals

Use `if (condition) { }` to conditionally render content:

**Basic condition:**

```html
if (is_admin) {
  <a href="/admin">Admin Panel</a>
}
```

**Negation:**

```html
if (!is_guest) {
  <p>Welcome back!</p>
}
```

**Else branch:**

```html
if (logged_in) {
  <a href="/logout">Logout</a>
} else {
  <a href="/login">Login</a>
}
```

**Else if chain:**

```html
if (role == "admin") {
  <li>Admin Panel</li>
} else if (role == "moderator") {
  <li>Moderator Tools</li>
} else {
  <li>Standard User</li>
}
```

**Comparison operators:** `==`, `!=`, `<`, `<=`, `>`, `>=`

```html
if (age >= 18) {
  <p>You can vote!</p>
}
```

**List length:**

```html
if (users.len > 0) {
  <p>{ users.len } users found</p>
}
```

**Logical AND / OR:**

```html
if (is_admin or is_moderator) {
  <button>Moderate</button>
}

if (is_logged_in and is_premium) {
  <p>Premium features unlocked!</p>
}
```

Boolean strings `"true"`, `"1"`, `"yes"` evaluate to true. `"false"`, `"0"`, `"no"` evaluate to false. Empty string and missing variables evaluate to false.

## Loops

Use `for (items) |item| { }` to iterate over a slice:

**Template:**

```html
<ul>
for (items) |item| {
  <li>{ item.value }</li>
}
</ul>
```

**Handler:**

```zig
const Item = struct { value: []const u8 };

pub fn data(c: *spider.Ctx) !spider.Response {
    const items = &[_]Item{
        .{ .value = "Lunas" },
        .{ .value = "Maylla" },
    };
    return c.view("data", .{ .items = items }, .{});
}
```

**Result:**

```html
<ul>
<li>Lunas</li>
<li>Maylla</li>
</ul>
```

## Coalescing operator

Use `{ expr ?? "default" }` to provide a fallback value when a variable is empty or missing:

```html
<h1>{ title ?? "Default Title" }</h1>
<p>{ description ?? "No description available" }</p>
```

Quoted strings as body content (e.g., `if (x) { "my-class" } else { "other" }`) are emitted as plain text without quotes.

## Layouts & extends

Use layouts to share structure across pages. The first line of a template must be `extends "layout_name"`.

**`src/shared/templates/layout.html`:**

```html
<!DOCTYPE html>
<html>
<head><title>{ title ?? "Spider App" }</title></head>
<body>
  <nav>...</nav>
  <main>
    { slot }
  </main>
</body>
</html>
```

**`src/features/home/views/index.html`:**

```html
extends "layout"

<h1>Welcome!</h1>
<p>This page uses the layout above.</p>
```

The `{ slot }` placeholder in the layout is replaced with the child template's content.

## Layout per Route

Spider supports multiple layouts for different routes:

**1. Create a custom layout:** `src/shared/templates/layout_docs.html` → normalizes to `layout_docs`

**2. Use `extends` in templates:**

```html
extends "layout_docs"

<h1>Docs Page</h1>
<p>This uses the docs-specific layout.</p>
```

## Components (PascalCase)

Create reusable components in `shared/templates/`. They are automatically available as PascalCase in any template.

**`src/shared/templates/site-nav.html`:**

```html
<nav class="site-nav">
  <a href="/">Home</a>
  <a href="/docs">Docs</a>
</nav>
```

Normalizes to `site_nav`. Use in any template as:

```html
<SiteNav />
```

The template engine converts `<SiteNav />` to `site_nav` automatically (PascalCase → snake_case).

## Named slots

Components can have named slots for injecting content:

**Component with slot:**

```html
<div class="card">
  { slot_header }
  <div class="card-body">
    { slot }
  </div>
</div>
```

**Using the component:**

```html
<Card>
  <h2 slot="header">Title</h2>
  Body content goes here
</Card>
```

## Markdown support

Templates ending with `.md` (or starting with `<!-- md -->`) are automatically converted from Markdown to HTML.

**`src/features/docs/views/quickstart.md`:**

```markdown
<!-- md -->

# Quick Start

This is **markdown** and it gets converted to HTML automatically.

- Item 1
- Item 2
```

Use `c.view("docs/quickstart", .{}, .{})` — Spider detects the `<!-- md -->` signature and converts markdown to HTML before rendering.

## Template modes

Spider has two template modes. Both produce **byte-identical output** — the only difference is when and where templates are loaded.

### Embed mode (recommended for production)

Templates are compiled into the binary — no files needed at runtime, ideal for Docker and production deployments.

Declare in `main.zig` or `root.zig` (must be in the root file of the executable):

```zig
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;
```

Spider detects this via `@hasDecl(@import("root"), "spider_templates")` — same pattern as `std_options` in the Zig stdlib.

### Runtime mode

Reads templates from disk at request time. Useful in development. Just don't declare `spider_templates` — Spider will scan `views_dir` automatically.

**Runtime mode requires `spider.config.zig`.**

Without it, Spider uses `views_dir = "./views"` as default, which rarely matches the actual project structure and causes `TemplateNotFound` errors.

Create `spider.config.zig` in your project root:

```zig
const spider = @import("spider");

pub const config = spider.Config{
    .views_dir = "./src",   // point to where your .html/.md files live
    .layout = "layout",
    .env = .development,
    .port = 3000,
    .host = "0.0.0.0",
};
```

Spider prints warnings to help diagnose configuration issues:

```
[spider] WARNING: views_dir "./views" not found.
[spider]          Templates will not load in runtime mode.
[spider]          Check your spider.config.zig -> views_dir setting.

[spider] WARNING: No templates found in "./views".
[spider]          Make sure your .html/.md files are inside views_dir.
[spider]          Check your spider.config.zig -> views_dir setting.

[spider] runtime templates: 5 loaded from "./src"
```

### Template name normalization

Both modes apply the same normalization rules. The name passed to `c.view()` is normalized the same way in both modes:

| File path (relative to views_dir) | Normalized name | Call with |
|---|---|---|
| `views/bills/index.html` | `bills_index` | `c.view("bills/index", ...)` |
| `views/home/index.html` | `home_index` | `c.view("home/index", ...)` |
| `shared/templates/layout.html` | `layout` | layout (auto, via config) |
| `shared/templates/Card.html` | `Card` | `c.view("Card", ...)` |
| `shared/templates/site-nav.html` | `site_nav` | `<SiteNav />` in templates |

Rules: strip extension → use segment after `views/` or `templates/` → replace `/` and `-` with `_`.

**Common mistake:** calling `c.view("index", ...)` when the file is at `views/bills/index.html`.
The correct call is `c.view("bills/index", ...)` which normalizes to `bills_index`.

### Embed mode in Docker

In embed mode, templates are inside the binary — no extra files needed:

```dockerfile
FROM <zig-image>:master AS builder
WORKDIR /app
COPY . .
RUN zig build -Doptimize=ReleaseSmall

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/zig-out/bin/<app> /app/<app>
COPY --from=builder /app/public /app/public
EXPOSE 3000
CMD ["./<app>"]
```

### Runtime mode in Docker

In runtime mode, templates must be copied into the container alongside the binary:

```dockerfile
FROM <zig-image>:master AS builder
WORKDIR /app
COPY . .
RUN zig build -Doptimize=ReleaseSmall

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/zig-out/bin/<app> /app/<app>
COPY --from=builder /app/public /app/public
COPY --from=builder /app/src /app/src
COPY --from=builder /app/spider.config.zig /app/spider.config.zig
EXPOSE 3000
CMD ["./<app>"]
```

## Auto-generate templates

Add to `build.zig` to automatically embed all `.html` and `.md` files at build time:

```zig
const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
gen.addArg("src/");
gen.addArg("src/embedded_templates.zig");
exe.step.dependOn(&gen.step);
```

Files are discovered automatically — add a new `.html` or `.md` file, rebuild, and it's available by name via `c.view()`.

### Registering spider.config.zig in build.zig

For Spider to read your `spider.config.zig`, register it as an anonymous import on `spider_mod`. Spider's `build.zig` provides a default config fallback — your project overrides it:

```zig
const spider_dep = b.dependency("spider", .{ .target = target });
const spider_mod = spider_dep.module("spider");

// Register spider.config.zig if it exists — overrides Spider's default config
const config_exists = blk: {
    std.Io.Dir.cwd().access(b.graph.io, "spider.config.zig", .{}) catch break :blk false;
    break :blk true;
};
if (config_exists) {
    spider_mod.addAnonymousImport("spider_config", .{
        .root_source_file = b.path("spider.config.zig"),
    });
}
```

> **Note:** Use `b.graph.io` to check file existence in `build.zig` — this is the correct Zig 0.17 API. `b.pathExists()` does not exist and `std.fs.cwd().access()` is the old API.

## Tag reference

| Tag | Syntax | Description |
|-----|--------|-------------|
| Interpolation | `{ variable }` | Render variable value |
| Coalescing | `{ var ?? "default" }` | Fallback for empty/missing values |
| Conditional | `if (condition) { ... }` | Conditional block |
| Else if | `} else if (condition) {` | Else-if branch |
| Else | `} else {` | Else branch |
| For loop | `for (items) \|item\| { ... }` | Iterate over slice with capture |
| Extends | `extends "layout"` | Use a layout (first line only) |
| Slot | `{ slot }` | Placeholder in layout/component |
| Named slot | `{ slot_header }` | Named placeholder |
| Component | `<ComponentName />` | Self-closing PascalCase component |
| Component with slot | `<ComponentName>...</ComponentName>` | PascalCase component with slot content |
