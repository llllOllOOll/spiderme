---
title: htmx
section: guide
order: 130
---

# htmx

With [htmx](https://htmx.org) a page asks the server for HTML and puts it in place, without a script of its own. Spider's side of it is small: handlers answer with HTML as they always do, and a few helpers cover the places where an htmx request needs a different answer.

The code on this page is from [Bookings](https://bookings.spiderme.org), the example app in `examples/bookings` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/bookings)). It uses **htmx 4**. A project is on htmx 2 or on htmx 4; what differs is said where it matters.

## Which htmx

```bash
spider new bookings --htmx=4
```

Without the flag a new project is on htmx 2. Either way `spider install` downloads the script to `public/js` (it is not kept in git), and the layout loads it:

```html
<script defer src="/js/htmx4.min.js"></script>
<script defer src="/js/htmx4-sse.min.js"></script>
```

The second line is the SSE extension, for [live pages](/docs/live). On htmx 2 the file is `/js/htmx.min.js`.

## A link that also works without it

The day view filters its rooms by what they have. Each filter is an ordinary link to an ordinary address, and htmx is added on top:

```html
<a class="ui-chip" href="{ filter.href }" aria-pressed="false"
   hx-get="{ filter.href }" hx-target="#day" hx-select="#day" hx-swap="outerHTML" hx-push-url="true">{ filter.label }</a>
```

With htmx the click asks for the same address, takes `#day` out of the page that comes back (`hx-select`), puts it where the current `#day` is, and writes the address in the browser's bar. Without htmx it is a link.

The handler does not know the difference. It renders the whole page for both, so the address works when it is opened in a new tab, shared or reloaded, and there is one template to keep right. Rendering only the part is an optimization for later: see `c.isHtmx()` below.

## A form

```html
<form action="/bookings/create" method="post"
      hx-post="/bookings/create" hx-target="#booking" hx-select="#booking" hx-swap="outerHTML">
    ...
    <button type="submit" hx-disable="this">Book room</button>
</form>
```

`hx-disable="this"` keeps the button from being pressed twice while the request is on its way (htmx 2 calls it `hx-disabled-elt`).

The handler has two answers:

```zig from=examples/bookings/src/features/bookings/controller.zig decl=create
```

**Refused**, the form page comes back with a 422 and what is wrong beside its field. htmx 4 swaps a 4xx like any other answer, so the form on screen is replaced by the one with the messages, and what was typed is still there because the handler rendered it back. htmx 2 does not swap an error status unless the page asks it to.

**Made**, the visitor goes to the booking's page, and that is the one place where an htmx request needs another answer. A redirect (303) is followed by the browser before htmx sees it: htmx would receive the booking's page as the content for `#booking` and stay on the form's address. `c.htmxRedirect(url)` answers what each caller needs: a request htmx made gets a 200 with the address in the `HX-Redirect` header, and htmx goes there; any other request gets the 303.

The test asks both ways:

```zig from=examples/bookings/src/pages_test.zig decl="booking: a form htmx posted is answered for htmx"
```

`"HX-Request: true"` is the header htmx sends with every request: with it in a test, the handler answers as it would to htmx.

## A page that asks again

A held booking runs out after ten minutes, and its page shows the minutes left. It asks for itself every twenty seconds:

```html
<main id="booking" hx-get="/bookings/{ booking.id }" hx-trigger="every 20s" hx-select="#booking" hx-swap="outerHTML">
```

The day view does the same when the server says something changed, instead of on a timer: `hx-trigger="changed from:body"`, where `changed` is an event that arrives on a stream. [Live pages](/docs/live) shows both ends of it.

## What the server can tell htmx

A handler reads what kind of request it has, and says more than HTML through response headers:

- `c.isHtmx()` is true for a request htmx made. A handler can then render only the part that changes instead of the page. `c.isBoosted()` is true for a navigation made through `hx-boost`.
- `c.htmxRedirect(url)`: where to go after a form, as above.
- `c.htmx(.{ ... })` builds response headers for the last argument of `c.html` or `c.view`: `.trigger` (an event for the page), `.retarget` and `.reswap` (put this answer somewhere else, or another way), `.reselect`, `.push_url`, `.replace_url`, `.redirect`, `.location`, `.refresh`. `.trigger_after_swap` and `.trigger_after_settle` are for htmx 2 only: htmx 4 ignores those headers.
- `c.hxEvent(name, data)` writes the value of `.trigger` for an event that carries data.
- `spider.varyHtmx` is a middleware that adds `Vary: HX-Request` to HTML responses. Use it when a handler answers htmx with a part and everyone else with the page at the same address: a cache then keeps the two apart.
- `spider.errorHandler` answers an error on an htmx request with its status, `HX-Reswap: none` and an `HX-Trigger` event (`spider:toast`, with a message and a type), so the page can say what went wrong without losing what is on screen. The page has to listen for the event.

## htmx 2 and htmx 4

What changes for the code on this page:

- An error status (4xx, 5xx) is swapped by htmx 4 and not by htmx 2. On htmx 2 the form above needs the page to allow the 422.
- `hx-disable` on htmx 4 is `hx-disabled-elt` on htmx 2.
- On htmx 4 an attribute no longer applies to the elements inside the one that has it. Where a parent sets `hx-target` for its children, it says so: `hx-target:inherited`.
- Streams: `hx-sse:connect` and an event in the page on htmx 4; `hx-ext="sse"`, `sse-connect` and `sse-swap` on htmx 2.
- `c.htmxRedirect`, `c.isHtmx()` and `HX-Redirect` work the same on both.
