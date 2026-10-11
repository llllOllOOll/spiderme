---
title: Push notifications
section: guide
order: 200
---

# Push notifications

Web Push shows a notification on someone's phone or computer when the app is closed: a booking was confirmed, a ticket was answered. The message goes from the app to a push service the browser's maker runs, and from there to the device. `spider.push` does the app's part: it encrypts the message so that only that browser reads it, signs it as coming from your app, and sends it.

The code on this page is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): tests that send to a push service of their own. What the browser does is described, not shown: it needs a person to allow notifications.

## The three parts

1. **The app's keys**, made once. They say that a message comes from your app.
2. **A subscription**, per browser: what the browser gives the page when the visitor allows notifications. The app stores it.
3. **A message**, sent to a subscription whenever there is something to say.

## The keys

```bash
spider generate-vapid mailto:ops@example.com
```

It prints three lines for `.env`: `VAPID_SUBJECT`, `VAPID_PUBLIC_KEY` and `VAPID_PRIVATE_KEY` (the [CLI page](/docs/cli) shows the output). The subject is how a push service can reach whoever runs the app. `spider.push.WebPush.initFromEnv()` reads the three.

Make the pair once and keep it: subscriptions are tied to the public key, and a new pair loses every subscriber. The private key is a secret; the public one goes to the page.

```zig from=examples/guide/src/push_test.zig decl="push: the keys are made once; the public one goes to the page"
```

## The browser's side

`spider add pwa` gives the project a service worker (`public/sw.js`), the script a browser keeps running for the site. It already shows a notification for each message that arrives, and opens the app at the message's address when the notification is clicked. A message is JSON with `title`, `body`, `url` and `tag`.

Asking the visitor is the app's to write, because when to ask is a decision: after they did something that makes a notification useful, never on the first page. The page then:

1. asks the browser for a subscription (`registration.pushManager.subscribe`), giving the app's public key as `applicationServerKey`;
2. posts what it gets (`subscription.toJSON()`) to the app;
3. the app stores its three values with the account: `endpoint`, `keys.p256dh` and `keys.auth`.

One account can have several subscriptions: a phone, a laptop. An endpoint is a secret of sorts, since whoever holds a subscription can try to push to that device: keep it out of logs.

## Sending

```zig from=examples/guide/src/push_test.zig decl=Browser decl="push: a message goes to the browser's push service, encrypted and signed"
```

- `sendRaw(arena, io, subscription, payload, ttl)` is for outside a request: a [job](/docs/jobs), a start-up task. In a handler, `send(c, subscription, payload, ttl)` uses the request's memory.
- The payload is bytes: JSON, by the service worker's convention above.
- `ttl` is how many seconds the push service keeps the message for a device that is offline. A message that is useless an hour later should not arrive a day later.

Sending waits for the push service to answer. To notify many devices, do it in a job, not in the request that caused it.

## When a subscription is gone

A visitor turns notifications off, clears the browser or changes phone, and nobody tells the app. The push service does, the next time the app sends:

```zig from=examples/guide/src/push_test.zig decl="push: a subscription the browser dropped says so, and the app forgets it"
```

- `error.PushSubscriptionExpired`: delete the subscription.
- `error.PushForbidden`: the subscription was made with other keys. It happens after the app's keys were changed: delete it too.
- `error.PushSendFailed`: the service refused for another reason, and the log has the status. Try again later.
- `error.InvalidKeyLength`: the stored subscription is damaged or was forged. Nothing is sent.

## How much fits

One message carries up to `spider.push.max_payload_len` bytes, 3993. Send what the notification shows and an address, and let the app load the rest when it opens:

```zig from=examples/guide/src/push_test.zig decl="push: a message has a size limit"
```
