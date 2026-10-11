---
title: QR codes
section: guide
order: 200
---

# QR codes

`spider.qrcode` turns a text, usually a link, into a QR code: a ticket to scan at the door, a payment, a page to open on a phone. It gives the squares; the app draws them.

The code on this page is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): a small server kept as tests, for what the example apps do not use.

## Turning it on

In `build.zig`, where the Spider dependency is declared, next to the other parts a project asks for by name:

```zig from=examples/guide/build.zig
```

## A code as SVG

```zig from=examples/guide/src/server.zig decl=ticketQr
```

- `QR.encodeAuto(allocator, text, level)` picks the smallest code the text fits in.
- `qr.size` is how many squares (modules) a side has, and `qr.getModule(x, y)` is true for a dark one.
- The level is how much of a damaged or covered code a scanner can still read: `.low` (about 7%), `.medium` (15%), `.quartile` (25%), `.high` (30%). A higher level makes a larger code for the same text. `.medium` suits a screen; go higher for print that gets folded or stained.
- The light margin around the code is part of it: without four modules of it, many scanners do not find the code.

SVG has no size of its own, so the page decides it:

```html
<img src="/tickets/A7K2/qr.svg" alt="Ticket A7K2" width="240" height="240">
```

The code this handler draws was read back with a scanner: it gives `https://guide.example/tickets/A7K2`.

```zig from=examples/guide/src/files_test.zig decl="qrcode: a link becomes a square of modules, drawn as SVG"
```

## How much fits

The more text, the more squares, and the harder the code is to scan from a distance: keep links short. A text that does not fit even the largest code is `error.DataTooLarge`:

```zig from=examples/guide/src/files_test.zig decl="qrcode: the size follows the text, and a text too long is an error"
```

`QR.encode(allocator, text, version, level)` takes the size instead of picking it: a version from 1 (21 modules a side) to 40 (177), for when every code of a series has to be the same size.

## What goes in a code

Anyone can read a QR code, and anyone can make one. Put a link or an id in it, not a secret, and check on the server what the id is allowed to do, as for any address a visitor can type.
