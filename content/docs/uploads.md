---
title: Uploads and downloads
section: guide
order: 40
---

# Uploads and downloads

A form sends a file when it says `enctype="multipart/form-data"`:

```html
<form action="/photos" method="post" enctype="multipart/form-data">
    <input type="text" name="caption">
    <input type="file" name="photo" accept="image/png">
    <button type="submit">Send</button>
</form>
```

The code on this page is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): a small server kept as tests, for what the example apps do not use.

## Taking a file

```zig from=examples/guide/src/server.zig decl=max_photo_bytes,addPhoto,isPng
```

`c.parseMultipart()` reads the form. `getValue(name)` is a text field, `getFile(name)` the files of a field: a list, because an input with `multiple` sends several. Each file has:

- `data`: its bytes. They live as long as the request, in memory.
- `size`: how many.
- `filename`: the name on the visitor's computer, as the browser sent it.
- `content_type`: what the browser says the file is.

```zig from=examples/guide/src/uploads_test.zig decl="upload: a photo and its caption arrive together"
```

## What not to believe

The name and the content type come from the visitor, and nobody checked them. Two rules follow:

- **Decide by the bytes.** A file called `team.png` and sent as `image/png` can be anything. Look at how it starts, as `isPng` does, or hand it to something that really reads the format.
- **Never use the name as a path.** It can be `../../etc/passwd`. Store the file under a name the app makes (an id, a random string) and keep the visitor's name, if it is wanted, as text in the database.

```zig from=examples/guide/src/uploads_test.zig decl="upload: the app decides by the bytes, whatever the browser called the file"
```

A body that is not a multipart form makes `parseMultipart` fail, and the visitor gets a 400 without the handler doing anything:

```zig from=examples/guide/src/uploads_test.zig decl="upload: a form without the file, and a body that is not a form"
```

## How large

The whole request is read into memory before the handler runs, and `max_body_bytes` in `spider.config.zig` is the most the server reads: 10 MiB unless the config says otherwise. A larger request gets a 413 and never reaches the handler.

```zig from=examples/guide/spider.config.zig
```

That limit is for every route. The limit of one form is the handler's, as `max_photo_bytes` above. For large files (video, backups), do not pass them through the app: let the browser send them straight to storage with a signed address.

## Sending a file

`c.download` answers with bytes the browser saves under the name given:

```zig from=examples/guide/src/server.zig decl=photoReport
```

```zig from=examples/guide/src/uploads_test.zig decl="download: the browser saves the file under the name the app gives"
```

The name may come from data: it is cleaned before it goes into the header. `.disposition = .@"inline"` lets the browser show the file (a PDF, an image) instead of saving it. The answer always says `X-Content-Type-Options: nosniff`, so a browser does not take the file for something else.

Files that are part of the app (stylesheets, scripts, images) are not sent this way: see [Static files](/docs/static).
