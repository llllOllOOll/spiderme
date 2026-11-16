---
title: Templates
section: guide
order: 120
---

# Templates

A template is an HTML file with values in braces. `c.viewChecked` renders one with the data a handler gives it, and checks that data when the app compiles.

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

The layout sees the same data as the page. `{ title ?? "Posts" }` uses the title the handler sent, or "Posts" when it sent none: `??` gives a default for a value that is missing. A missing value is `null`, so `if (composing == null)` shows the button on every page except the form, the one handler that sends `composing`.

`current_user` is there on every page without any handler sending it: Spider fills it in when someone is signed in, with `id`, `email` and `name`. Nobody signed in, no `current_user`, and the layout offers to sign in. A component can read it too.

## Components

A template can be used as a tag: `PostCard.html` is `<PostCard>`. The feed above writes one for each post. This is the component:

```html from=examples/posts/src/features/posts/views/PostCard.html
```

[Components](/docs/components) is the page about them: attributes, the props a component declares, what goes inside the tag, components made of components, and sending one alone to htmx.

### A layout without `extends`

A page can also get its layout from its route, without naming it: `.layout = "admin"` in the route's config, or in `defaults(...)` for a whole group, and `""` for none. `default_layout` in `spider.config.zig` is the one for every page whose route names none. It never applies to a template that is a whole document (it has `<html`), to an htmx request that is not boosted, to `c.viewFragment` or to a Markdown view.

## Checked when the app compiles

`c.viewChecked` compares the data with what the template reads, and what its layout and its components read, when the app compiles. The layout of Posts reads `composing`; had it been written `if (!composing)`, every view would have needed that field, and the build would have stopped with one error per view, naming what is missing and what the data has:

```text
error: view "posts/index" (in <layout>): `composing`: the data has no field `composing` (it has: title, q, searching, posts)
```

What it catches: a template that does not exist, a field that is not there (`posts[].titel`), a value a template cannot print, a struct printed as text, a `for` over something that is not a list, and a component's prop of the wrong type. A name the template reads only behind `??` or `== null` may be missing, and so may a prop the component declares and a call leaves out.

`c.view` renders the same template without the check. It is for a view whose name is chosen while the app runs; otherwise prefer `c.viewChecked`.

## A name that is not there

With `c.view`, a name the data does not have renders as nothing. `templates_strict` in `spider.config.zig` decides whether that is said: `.off` says nothing, `.warn` logs one line for each name and view, naming the components it was in, and `.error` fails the view (a 500). Unset, it is `.warn` in a Debug build and `.off` in a release build, so a misspelled name shows in the log of `spider dev`. A field that is there and `null` is not reported.

## Compiled templates

In a release build each template is also compiled into a Zig function, and `c.viewChecked` renders with it: the text is written straight from the template file and the data is read field by field, with no names looked up while the page is made. The HTML is the same, to the byte; Spider's tests render a set of templates both ways and fail on any difference.

What renders as before, with the same HTML:

- a Debug build, so that a saved template shows on the next request;
- `c.view`, whose template may be chosen while the app runs;
- `templates_strict` other than `.off`, since its warnings are made per request;
- a page without `extends` that gets its layout from its route;
- a template the compiler does not take: one that reads `current_user`, a condition that calls a function, a component that includes itself.

`compiled_templates = false` in `spider.config.zig` turns it off.

## HTML from Zig

Text is always escaped. To put markup your own code built into a page, wrap it in `spider.RawHtml`. Posts does it for the body of a post, which is written in Markdown:

```zig from=examples/posts/src/features/posts/controller.zig decl=show
```

`spider.zmd.parse` turns Markdown into HTML and escapes everything the author typed, so its result is safe to show as it is. Never wrap text a user typed that did not go through something that escapes it.

The template then uses `{ body }` like any other value:

```html from=examples/posts/src/features/posts/views/show.html
```

## Where templates are read from

In a debug build, which is what `spider dev` and `zig build run` make, templates are read from disk on every request: save the file and reload the page. In a release build they are compiled into the binary, so a deploy needs nothing but the binary. Either can be chosen for every build: see [The build](/docs/build#Templates-in-the-binary-or-on-disk).
