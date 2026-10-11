---
title: Login
section: guide
order: 90
---

# Login

```bash
spider g auth
```

It adds a login to the project: accounts are a table of the app, a password is stored as a hash, and being signed in is a cookie the app signs. Nothing outside the app is involved.

It writes the feature `src/features/auth/`, a migration for the `users` table, tests of the whole flow, and one line in `src/main.zig`. Then:

- `/auth/register` creates an account,
- `/auth/login` signs in,
- `/auth/account` shows who is signed in, with a button to sign out.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)), where the command was run and its screens were restyled.

## Who may call a route

After the command, a route that does not say `.public` needs someone signed in. A visitor without a session is sent to `/auth/login`.

Each route says who may call it, in its config:

- `.public = true`: anyone.
- `.authenticated = true`: anyone who is signed in.
- `.roles = &.{"admin"}`: someone signed in whose role is one of these.
- `.policy = ...`: someone signed in who passes a rule of the app, such as "wrote this post". [Access policies](/docs/policies) is about those.

Posts lets everyone read and asks for a login to write:

```zig from=examples/posts/src/features/posts/routes.zig decl=build
```

A handler behind `.authenticated` can count on the visitor. Posts takes the author of a new post from there:

```zig from=examples/posts/src/features/posts/controller.zig decl=create,signedInName
```

`c.userId()` gives the id of the account, as text, or null when nobody is signed in.

## Who is signed in, on the page

Every template can read `current_user`: its `id`, `email` and `name`. Handlers do not pass it. The layout of Posts uses it for the top of every page:

```html from=examples/posts/src/shared/templates/layout.html
```

## Features made before the login

A feature generated before the login has routes that say nothing about who may call them. Once there is a login, `spider check` and `zig build test` point at each one.

Two edits settle it. In the feature's `routes.zig`, the line that sets the defaults is there, commented out; put the access you want in it:

```zig
        .defaults(.{ .authenticated = true })
```

And in its `routes_test.zig`, the table says who may call each route. Change the `"-"` of each line to match:

```zig
        .{ "GET", "/posts", "authenticated" },
```

## The middleware

The line the command adds to `src/main.zig` is `.use(spider.session.middleware())`. On every request it reads the cookie, checks that the app signed it, and tells the routes who is there. It also changes the error handler, so that a visitor who is not signed in is sent to the sign-in page:

```zig from=examples/posts/src/main.zig decl=serve,fallback
```

## Signing in

The generated controller checks the password and starts the session. A password is never stored or compared as it is: `spider.password.hash` makes what goes in the table, and `spider.password.verify` checks a password against it.

```zig from=examples/posts/src/features/auth/controller.zig decl=login
```

An email with no account gets the same answer as a wrong password, after the same work, so the form does not tell a stranger which emails are registered.

`spider.session.start` gives the response options that set the cookie:

```zig from=examples/posts/src/features/auth/controller.zig decl=signIn
```

Signing out is `spider.session.end`:

```zig from=examples/posts/src/features/auth/controller.zig decl=logout
```

## Creating an account

```zig from=examples/posts/src/features/auth/controller.zig decl=register
```

The rules are in the model, next to the user: a name, an email that looks like one, a password of at least 8 characters. The email is stored in lower case, so `Ana@Example.com` and `ana@example.com` are one account.

Registration is open to anyone. To close it, remove the two `/auth/register` routes.

## Roles

A new account has the role `user`. The role is a column of the `users` table, and it travels in the session. To make someone an admin, change the row:

```sql
UPDATE users SET role = 'admin' WHERE email = 'ana@example.com';
```

That account then passes `.roles = &.{"admin"}` the next time it signs in.

## The secret

Sessions are signed with `JWT_SECRET`, in `.env`. `spider new` writes a random one. Keep the one of production out of git, and know that changing it signs everyone out.

Without one, `spider dev` makes one up each time the app starts, so everyone is signed out on a restart. A release build, the one you deploy, refuses to sign anyone in until `JWT_SECRET` is set.

A session lasts 14 days. It cannot be ended from the server before that: there is no list of sessions to remove it from.

## For an API

```bash
spider g auth --api
```

It generates JSON routes instead of pages. `POST /auth/register` and `POST /auth/login` answer a token, and the client sends it back on every request:

```text
Authorization: Bearer <token>
```

## Keycloak

`spider g auth --provider=keycloak` generates a login through a Keycloak realm instead: the accounts and the sign-in page are Keycloak's. [Login with a provider](/docs/login-providers) shows it, and signing in with Google.

## What is not there yet

Password reset, email confirmation, a limit on sign-in attempts and two-factor are not generated.
