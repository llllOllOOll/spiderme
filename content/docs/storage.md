---
title: File storage (R2)
section: guide
order: 50
---

# File storage (R2)

Files people upload should not live on the server's disk: a new deploy is a new container, and the disk goes with the old one. `spider.r2` keeps them in a bucket of [Cloudflare R2](https://developers.cloudflare.com/r2/), and lets a browser send and fetch files there directly, without passing them through the app.

The code on this page is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): a small server kept as tests, for what the example apps do not use. Its tests cover what needs no network: the client, the names and the signed addresses. The calls that talk to R2 are compiled, not run.

## Turning it on

In `build.zig`, where the Spider dependency is declared:

```zig from=examples/guide/build.zig
```

## One client, made at start

```zig from=examples/guide/src/server.zig decl=run
```

An app reads the values from the environment instead: `spider.r2.R2.initFromEnv(io)` takes `R2_ACCOUNT_ID`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET` and, for a bucket with a public domain, `R2_PUBLIC_URL`. The keys are those of an R2 API token.

Making the client calls nobody, so wrong keys show at the first operation. Missing ones show right away:

```zig from=examples/guide/src/storage_test.zig decl="storage: a client without its account, keys or bucket is refused when it is made"
```

Make one client for the whole app and share it, as `store` here: it keeps its connections open between calls.

## The browser uploads straight to the bucket

The app does not receive the file. It gives the browser an address that accepts one upload for a few minutes, and the browser sends the file there with a `PUT`:

```zig from=examples/guide/src/server.zig decl=store,signAvatarUpload
```

```zig from=examples/guide/src/storage_test.zig decl="storage: the browser gets an address to upload to, signed for a few minutes"
```

- `presignedPut(allocator, key, content_type, seconds)` signs the address. The upload has to send the same `Content-Type`: it is part of the signature, so an address signed for a PNG takes nothing else.
- The app chooses the key. Nothing of it should come from the visitor: see [Uploads and downloads](/docs/uploads) for why.
- `objectKey(allocator, account, category, filename)` joins the three with `/`: one folder per account keeps the files of each apart.
- `publicUrl(allocator, key)` is the address of the object on the bucket's public domain, for files anyone may see.

The app's own limit on request bodies does not apply to an upload that goes to the bucket, which is the point for large files. Allow the site's address in the bucket's CORS settings, or the browser refuses to send.

## A private file

For a file only its owner may see, the bucket has no public domain. The app checks who is asking, then sends them to an address that works for a short time:

```zig from=examples/guide/src/server.zig decl=invoice
```

```zig from=examples/guide/src/storage_test.zig decl="storage: a private file is reached through an address that lasts a minute"
```

Signing calls nobody, so an address is made for a key that does not exist too: the visitor then gets R2's own "not found".

## Files the app handles itself

For what the app makes or reads (a report, an export, a file it has to look into), the client talks to R2:

```zig from=examples/guide/src/server.zig decl=keepReport
```

- `put(c, key, bytes, content_type)` writes an object, replacing one that is there.
- `get(c, key)` reads one whole into the request's memory; `error.NotFound` when there is none, which a handler can let through as a 404.
- `head(c, key)` says whether it exists, without reading it.
- `delete(c, key)` removes it, and `copyObject(c, from, to)` copies it inside the bucket without downloading.

Each takes the request's `c`. A failure is an error by name (`error.R2PutFailed`, `error.R2GetFailed` and so on), with R2's answer in the log.
