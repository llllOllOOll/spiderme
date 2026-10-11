---
title: Static files
section: guide
order: 220
---

# Static files

Files in the `public` folder are served as they are: `public/favicon.png` is `/favicon.png`, and `public/fonts/onest.woff2` is `/fonts/onest.woff2`. Nothing has to be registered.

They are answered before any route or middleware runs, so a static file never needs a login.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)).

## What goes there

Images, fonts, icons, and the stylesheet. In a project with pages, the build compiles `src/styles.css` into `public/css/app.css`, and the layout links to it:

```html from=examples/posts/src/shared/templates/layout.html
```

`public/css/app.css` is made by the build and is not kept in git. Files you put in `public` yourself are.

## Caching

Every file is sent with an `ETag`, a fingerprint of its content, and browsers are told to check it before using their copy. When the file has not changed the answer is `304`, with no body, so the file is not downloaded again.

For a file that never changes under its address, add `?v=` and anything after it. The answer then tells the browser to keep the file for a year without asking. Posts does it for its fonts:

```css from=examples/posts/src/styles.css
```

When such a file does change, change the number, and every browser fetches the new one.

## Another folder

`static_dir` in `spider.config.zig` names the folder; `./public` is the default. `null` serves no static files. See [Configuration](/docs/configuration).

## Limits

- A folder address, like `/fonts/`, is not a listing: it answers 404.
- An address cannot reach outside the folder: `/../build.zig` answers 404.
