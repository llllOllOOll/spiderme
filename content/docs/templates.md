---
title: Templates
section: guide
order: 120
---

# Templates

A template is an HTML file with values in braces. `c.view` renders one with the data a handler gives it.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)). This is the handler of its feed:

```zig from=examples/posts/src/features/posts/controller.zig decl=index
```

The name is the feature and the file: `"posts/index"` is `src/features/posts/views/index.html`. The data is a struct: text, numbers, booleans, optionals, other structs and slices of structs.

## Values, conditions and loops

And this is the template it renders:

```html from=examples/posts/src/features/posts/views/index.html
```

- `{ q }` puts a value in the page. It is escaped: a `<` in the data reaches the page as `&lt;`.
- `if (searching) { ... } else { ... }` shows one part or the other. Conditions take `==`, `!=`, `<`, `>`, `and`, `or` and `!`.
- `for (posts) |post| { ... }` repeats a part for each item, and `post.title` reads a field of it.
- `posts.len` is how many there are.

## Layouts

A layout is a template with a `{ slot }` where the page goes. A page names its layout on its first line, as `extends "layout"` does above. This is the layout of Posts, `src/shared/templates/layout.html`:

```html from=examples/posts/src/shared/templates/layout.html
```

The layout sees the same data as the page. `{ title ?? "Posts" }` uses the title the handler sent, or "Posts" when it sent none: `??` gives a default for a value that is missing. In a condition a missing value counts as false, so `if (!composing)` shows the button on every page except the ones that send `composing`.

`current_user` is there on every page without any handler sending it: Spider fills it in when someone is signed in, with `id`, `email` and `name`. Nobody signed in, no `current_user`, and the layout offers to sign in. A component can read it too.

## Components

A template can be used as a tag. The tag is the file name in PascalCase: `PostCard.html` and `post-card.html` are both `<PostCard>`. Its attributes become its values, and what is written inside the tag becomes its `{ slot }`.

The feed above writes one `<PostCard ... />` for each post. This is the component:

```html from=examples/posts/src/features/posts/views/PostCard.html
```

A component lives next to the views of its feature, or in `src/shared/templates` when several features use it, like the link that goes back a page:

```html from=examples/posts/src/shared/templates/back-link.html
```

## HTML from Zig

Text is always escaped. To put markup your own code built into a page, wrap it in `spider.RawHtml`. Posts does it for the body of a post, which is written in Markdown:

```zig from=examples/posts/src/features/posts/controller.zig decl=show
```

`spider.zmd.parse` turns Markdown into HTML and escapes everything the author typed, so its result is safe to show as it is. Never wrap text a user typed that did not go through something that escapes it.

The template then uses `{ body }` like any other value:

```html from=examples/posts/src/features/posts/views/show.html
```

## Where templates are read from

In a debug build, which is what `spider dev` and `zig build run` make, templates are read from disk on every request: save the file and reload the page. In a release build they are compiled into the binary, so a deploy needs nothing but the binary.
