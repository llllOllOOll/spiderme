---
title: Mail
section: guide
order: 54
---

# Mail

`spider.mail` sends mail through a provider's API: Brevo, Resend or Postmark. It is not a mail server, and there is no SMTP. While you develop, it writes the mail to the log.

The code on this page is from Bookings, the example app in `examples/bookings`, which mails whoever booked a room when the booking is confirmed.

## A mailer

Make the mailer once, when the app starts, and keep it:

```zig from=examples/bookings/src/features/bookings/notify.zig decl=mailer,boot
```

`Mailer.fromEnv` reads how mail leaves from the environment:

- `MAIL_TRANSPORT`: `brevo`, `resend`, `postmark` or `log`. Without it, `log`: the mail is written to the log and nothing is sent.
- `BREVO_API_KEY`, `RESEND_API_KEY` or `POSTMARK_SERVER_TOKEN`: the key of the provider that was chosen.
- `MAIL_FROM`: who the mail is from when a mail does not say, as `Name <address>`.
- `MAIL_TIMEOUT_MS`: how long one delivery may take. 30 seconds unless you say otherwise.

Keep the keys in the environment, as [Configuration](/docs/configuration) says.

## Sending

```zig from=examples/bookings/src/features/bookings/notify.zig decl=Owner,mail
```

A mail needs someone to send it to, and a body: `text`, `html`, or both. `mailer.send(c, mail)` sends from a handler. Outside a request, in a [job](/docs/jobs), it is `mailer.sendWith(arena, io, mail)`.

A name or a subject is checked before anything is sent: a line break in one of them is `error.MailInvalidHeader`, so text a visitor typed cannot add a header of its own.

## When it fails

`send` fails with an error that says whose problem it is:

- `error.MailUnauthorized`: the provider refused the key.
- `error.MailRejected`: the provider refused this mail. Sending it again unchanged will not help.
- `error.MailDeliveryFailed`: the network, a limit, the provider having a bad moment, or the time limit. Worth trying again later.

Decide what a failure means for the visitor. In Bookings a booking is confirmed whether or not its mail could be sent, so the failure goes to the log and the request goes on:

```zig from=examples/bookings/src/features/bookings/notify.zig decl=confirmed
```

Sending takes as long as the provider takes to answer, and the visitor waits for it. That is fine for one mail after a click. For many, queue them and send from a job.

## Testing

A test swaps the mailer for a box in memory and reads what was put in it:

```zig from=examples/bookings/src/pages_test.zig decl="booking: confirming it mails who booked and tells the webhook, once"
```

`outbox.count()`, `outbox.last()` and `outbox.sent()` give what was sent, as the `Mail` values the app built.
