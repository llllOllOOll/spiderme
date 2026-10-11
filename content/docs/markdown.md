---
title: Markdown
section: guide
order: 59
---

# Markdown

`spider.zmd` turns Markdown into HTML. It is part of Spider: nothing to install, nothing to turn on. This site is written with it, and so are the posts of [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)).

## Text someone typed, on a page

A post's body is Markdown in the database. The handler turns it into HTML and gives it to the template:

```zig from=examples/posts/src/features/posts/controller.zig decl=show
```

A template escapes every value it prints, so HTML in a value would show as text. `spider.RawHtml` says that this one value is HTML already and goes in as it is. That is safe here for one reason: `spider.zmd.parse` escapes everything the author typed. Never wrap in `RawHtml` text that did not go through it.

`parse(allocator, text, formatters)` gives back a fragment, to put inside a page. With `c.arena` there is nothing to free.

## What comes out

```zig from=src/features/docs/markdown_test.zig decl="markdown: what an author types, and the HTML that comes out"
```

A block of code gets a bar with its language, and classes to style it by:

```zig from=src/features/docs/markdown_test.zig decl="markdown: a block of code keeps its language and escapes its text"
```

What it does not read yet: tables, horizontal rules (`---`), strikethrough, and a link whose text is code. They come out as the text that was typed.

## What an author cannot do

HTML in the text is shown, not run. A link is kept only when its address is safe to follow: one that would run a script loses its link.

```zig from=src/features/docs/markdown_test.zig decl="markdown: HTML an author types is shown, not run; a link that would run a script is dropped"
```

## Your own HTML for an element

The third argument says how each kind of element is written. `.{}` is the default; name a field to replace one. A formatter gets the element (`node.content` is its inner HTML, already escaped) and returns its HTML:

```zig from=src/features/docs/markdown_test.zig decl=titled decl="markdown: a formatter of the app's own writes one kind of element"
```

This site gives its headings an `id` that way, so a page can be linked to at one of them:

```zig from=src/features/docs/controller.zig decl=headings
```

A formatter that prints `node.href`, `node.title` or `node.meta` has to escape them itself: those are what the author typed.

## A whole document

`parseFull` wraps the result in a complete HTML document, for a file that is opened by itself:

```zig from=src/features/docs/markdown_test.zig decl="markdown: parseFull gives a whole document"
```
