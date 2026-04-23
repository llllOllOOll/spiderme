-- md
{% extends "layout_docs" %}
{% block "content" %}
# Templates

Spider's template engine is embedded at compile time via `@embedFile`. Templates are discovered automatically and rendered server-side — no JavaScript build step, no dependencies.

## How it works

At build time, `generate-templates` scans your `src/` directory and embeds all `.html` and `.md` files into a single Zig struct:

```zig
// src/embedded_templates.zig — auto-generated, do not edit
pub const EmbeddedTemplates = struct {
    index: []const u8 = @embedFile("index.html"),
    data: []const u8 = @embedFile("data.md"),
    layout_docs: []const u8 = @embedFile("layout_docs.html"),
};
```

Spider loads this struct at startup and resolves templates by name at request time.

## Quick Start

**1. Create `src/index.html`:**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Spider App</title>
</head>
<body>
  <h1>Hello, {{ name }}!</h1>
</body>
</html>
```

**2. Create the handler in `src/main.zig`:**

```zig
fn home(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "index", .{
        .name = "Seven",
    });
}
```

**3. Register the route:**

```zig
server.get("/home", home).listen();
```

**4. Enable auto-generate in `build.zig`:**

```zig
const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
gen.addArg("src/");
gen.addArg("src/embedded_templates.zig");
exe.step.dependOn(&gen.step);
```

Visit `http://localhost:8080/home` — you'll see `Hello, Seven!`.

## Variable interpolation

Use `{{ variable }}` to render values from your handler context:

```html
<h1>{{ title }}</h1>
<p>Welcome, {{ user_name }}!</p>
<p>Items in cart: {{ count }}</p>
```

```zig
return spider.chuckBerry(alloc, req, "page", .{
    .title = "Dashboard",
    .user_name = "Alice",
    .count = "42",
});
```

Missing variables render as empty string — no errors, no crashes.

## Conditionals

Use `{· if ·}` to conditionally render content:

> **Note:** In these examples, `·` represents `%`. So `{· if condition ·}` means `{% if condition %}`. The `·` is used here because `{% %}` inside code examples would be interpreted by Spider's template engine.

**Basic condition:**

```html
{· if is_admin ·}
<a href="/admin">Admin Panel</a>
{· endif ·}
```

**Negation:**

```html
{· if !is_guest ·}
<p>Welcome back!</p>
{· endif ·}
```

**Else branch:**

```html
{· if logged_in ·}
<a href="/logout">Logout</a>
{· else ·}
<a href="/login">Login</a>
{· endif ·}
```

**Equality:**

```html
{· if status == "active" ·}
<span class="badge green">Active</span>
{· endif ·}
```

**Logical AND / OR:**

```html
{· if is_admin or is_moderator ·}
<button>Moderate</button>
{· endif ·}

{· if is_logged_in and is_premium ·}
<p>Premium features unlocked!</p>
{· endif ·}
```

Boolean strings `"true"`, `"1"`, `"yes"` evaluate to true. `"false"`, `"0"`, `"no"` evaluate to false. Empty string and missing variables evaluate to false.

## Loops

Use `{· for ·}` to iterate over a slice:

**`src/data.md`:**

```html
<ul>
{· for item in items ·}
<li>{{ item.value }}</li>
{· endfor ·}
</ul>
```

**Handler:**

```zig
fn dataPage(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    const Item = struct { value: []const u8 };
    const Data = struct { items: []const Item };

    return spider.chuckBerry(alloc, req, "data", Data{
        .items = &[_]Item{
            .{ .value = "Lunas" },
            .{ .value = "Maylla" },
        },
    });
}
```

**Result:**

```html
<ul>
  <li>Lunas</li>
  <li>Maylla</li>
</ul>
```

## HTMX fragments

Spider detects `HX-Request` headers automatically. When a request comes from HTMX, `chuckBerry` returns only the `{· block "content" ·}` fragment — not the full layout. This means the same handler works for both full page loads and HTMX partial updates.

**`src/index.html`:**

```html
<button
  hx-get="/data"
  hx-swap="innerHTML"
  hx-target="#container"
>
  Load data
</button>
<div id="container"></div>
```

**`src/data.md`:**

```html
{· for item in items ·}
<p>{{ item.value }}</p>
{· endfor ·}
```

Click the button — HTMX fetches `/data` and injects the fragment into `#container`. No page reload, no extra handler code.

## Layouts & extends

Use layouts to share structure across pages.

**`src/layout_docs.html`:**

```html
{· block "base" ·}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Spider Docs</title>
</head>
<body>
  <nav>...</nav>
  <main>
    {· template "content" ·}
  </main>
</body>
</html>
{· end ·}
```

**`src/page.md`:**

```
-- md
{· extends "layout_docs" ·}
{· block "content" ·}
# My Page

Content goes here.
{· end ·}
```

`chuckBerry` resolves the `{· extends ·}`, merges the blocks, and returns the full HTML. For HTMX requests it returns only the `content` block.

## Filters

Apply filters with the `|` pipe operator:

```html
<p>Hello {{ name | default:"Guest" }}!</p>
<p>Total: {{ amount | default:"0.00" }}</p>
```

If `name` is empty or missing, `"Guest"` is used instead. Currently supported filters:

- `default:"value"` — fallback when variable is empty or missing

## Auto-generate templates

Add to `build.zig` to automatically embed all `.html` and `.md` files at build time:

```zig
const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
gen.addArg("src/");
gen.addArg("src/embedded_templates.zig");
exe.step.dependOn(&gen.step);
```

Then import in `main.zig`:

```zig
const templates = @import("embedded_templates.zig").EmbeddedTemplates;

const server = try spider.Spider.init(arena, io, "127.0.0.1", 8080, .{
    .templates = templates,
});
```

Files are discovered automatically — add a new `.html` or `.md` file, rebuild, and it's available by name via `chuckBerry`.


## Rendering

Spider provides three rendering functions.

### render

Renders a template string directly. No layout, no blocks.

```zig
const html = try spider.template.render(tmpl, data, alc);
```

### Response.html

Wraps a raw `[]const u8` in an HTML response. No template rendering.

```zig
return spider.Response.html(alc, content);
```

### chuckBerry

The recommended function for handlers. Resolves the template by name, handles `{· extends ·}`, and detects HTMX requests automatically:

```zig
pub fn index(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    const context = try buildContext(alc, req);
    return spider.chuckBerry(alc, req, "home/index", context);
}
```



## Tag reference

> **Note:** In this table, `·` represents `%` in real usage.

| Tag | Usage | Description |
|-----|-------|-------------|
| `{{ variable }}` | `{{ name }}` | Interpolate variable value |
| `{{ \| filter }}` | `{{ name \| default:"Guest" }}` | Apply filter to variable |
| `{· if ·}` | `{· if is_admin ·}` | Conditional block |
| `{· elif ·}` | `{· elif is_mod ·}` | Else-if branch |
| `{· else ·}` | `{· else ·}` | Else branch |
| `{· endif ·}` | `{· endif ·}` | Close if block |
| `{· for ·}` | `{· for item in items ·}` | Loop over slice |
| `{· endfor ·}` | `{· endfor ·}` | Close for loop |
| `{· block ·}` | `{· block "content" ·}` | Define named block |
| `{· end ·}` | `{· end ·}` | Close block |
| `{· template ·}` | `{· template "content" ·}` | Include named block |
| `{· extends ·}` | `{· extends "layout" ·}` | Extend a layout |
| `{· include ·}` | `{· include "partial" ·}` | Include a template file |
| `{· raw ·}` | `{· raw ·}` | Output content literally |
| `{· endraw ·}` | `{· endraw ·}` | Close raw block |
{% end %}
