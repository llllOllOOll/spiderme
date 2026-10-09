---
title: Templates
section: guide
order: 50
---

# Templates

A template is an HTML file with values in braces. `c.view` renders one with the data a handler gives it.

```zig
const Post = struct { title: []const u8, comments: u32 };

fn index(c: *spider.Ctx) !spider.Response {
    const posts = [_]Post{
        .{ .title = "Hello", .comments = 2 },
        .{ .title = "Routing", .comments = 0 },
    };
    return c.view("posts/index", .{ .heading = "Posts", .posts = &posts, .signed_in = true }, .{});
}
```

The name is the feature and the file: `"posts/index"` is `src/features/posts/views/index.html`. The data is a struct: text, numbers, booleans, optionals, other structs and slices of structs.

## Values, conditions and loops

```html
<h1>{ heading }</h1>

if (signed_in) {
<p>Welcome back.</p>
} else {
<p>Please sign in.</p>
}

<ul>
for (posts) |post| {
    <li>{ post.title } ({ post.comments } comments)</li>
}
</ul>

<p>{ subtitle ?? "No subtitle" }</p>
```

`{ value }` is escaped: a `<` in the data reaches the page as `&lt;`. `??` gives a default for a value that is missing. Conditions take `==`, `!=`, `<`, `>`, `and`, `or` and `!`.

## Layouts

A layout is a template with a `{ slot }` where the page goes. A page names its layout on the first line.

```html
<!-- src/shared/templates/layout.html -->
<html>
<body>
    <main>{ slot }</main>
</body>
</html>
```

```html
extends "layout"

<h1>{ heading }</h1>
```

## Components

A template can be used as a tag. The tag is the file name in PascalCase: `post-card.html` and `PostCard.html` are both `<PostCard>`. Its attributes become its values, and what is inside the tag becomes its `{ slot }`.

```html
<!-- src/shared/templates/post-card.html -->
<article>
    <h2>{ title }</h2>
    { slot }
</article>
```

```html
<PostCard title="{ post.title }">
    <p>{ post.comments } comments</p>
</PostCard>
```

## HTML from Zig

Text is always escaped. To put markup your own code built into a page, wrap it in `spider.RawHtml`. Never wrap anything a user typed.

```zig
fn about(c: *spider.Ctx) !spider.Response {
    const badge = spider.RawHtml{ .html = "<strong>new</strong>" };
    return c.view("posts/about", .{ .badge = badge }, .{});
}
```

## Where templates are read from

In a debug build, which is what `spider dev` and `zig build run` make, templates are read from disk on every request: save the file and reload the page. In a release build they are compiled into the binary, so a deploy needs nothing but the binary.
