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
server.listen(8080) catch {};
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

Use `{ if condition }` to conditionally render content:

**Basic condition:**

```html
{ if is_admin }
  <a href="/admin">Admin Panel</a>
{ endif }
```

**Negation:**

```html
{ if !is_guest }
  <p>Welcome back!</p>
{ endif }
```

**Else branch:**

```html
{ if logged_in }
  <a href="/logout">Logout</a>
{ else }
  <a href="/login">Login</a>
{ endif }
```

**Equality:**

```html
{ if status == "active" }
  <span class="badge green">Active</span>
{ endif }
```

**Comparison operators:**

```html
{ if age >= 18 }
  <p>You can vote!</p>
{ endif }
```

**Logical AND / OR:**

```html
{ if is_admin or is_moderator }
  <button>Moderate</button>
{ endif }

{ if is_logged_in and is_premium }
  <p>Premium features unlocked!</p>
{ endif }
```

Boolean strings `"true"`, `"1"`, `"yes"` evaluate to true. `"false"`, `"0"`, `"no"` evaluate to false. Empty string and missing variables evaluate to false.

## Loops

Use `{ for item in items }` to iterate over a slice:

**Template:**

```html
<ul>
{ for item in items }
  <li>{ item.value }</li>
{ endfor }
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

## Filters

Apply filters with the `??` coalescing operator (more filters coming soon):

```html
<p>Hello { name ?? "Guest" }!</p>
<p>Total: { amount ?? "0.00" }</p>
```

If `name` is empty or missing, `"Guest"` is used instead.

## Template modes

### Embed mode (recommended)

Templates are compiled into the binary. Declare in `main.zig`:

```zig
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;
```

Spider detects this via `@hasDecl(@import("root"), "spider_templates")`.

### Runtime mode

Reads templates from disk. No config needed — just don't declare `spider_templates`.

## Auto-generate templates

Add to `build.zig` to automatically embed all `.html` and `.md` files at build time:

```zig
const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
gen.addArg("src/");
gen.addArg("src/embedded_templates.zig");
exe.step.dependOn(&gen.step);
```

Files are discovered automatically — add a new `.html` or `.md` file, rebuild, and it's available by name via `c.view()`.

## Tag reference

| Tag | Syntax | Description |
|-----|---------|-------------|
| Interpolation | `{ variable }` | Render variable value |
| Coalescing | `{ var ?? "default" }` | Fallback for empty/missing values |
| If | `{ if condition }` | Conditional block |
| Else if | `{ elif condition }` | Else-if branch |
| Else | `{ else }` | Else branch |
| End if | `{ endif }` | Close if block |
| For loop | `{ for item in items }` | Iterate over slice |
| End for | `{ endfor }` | Close for loop |
| Extends | `extends "layout"` | Use a layout (first line only) |
| Slot | `{ slot }` | Placeholder in layout |
| Named slot | `{ slot_header }` | Named placeholder |
| Component | `<ComponentName />` | Reusable PascalCase component |
| Raw | `{ raw }` | Output content literally |
| End raw | `{ endraw }` | Close raw block |
