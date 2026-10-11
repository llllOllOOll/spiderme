---
title: Login with a provider
section: guide
order: 100
---

# Login with a provider

[Login](/docs/auth) is about an app that keeps its own accounts and passwords. This page is about leaving that to someone else: the visitor signs in at a provider's page, and the provider tells the app who they are. The app never sees a password.

Spider has three: **Keycloak**, a server you run, which keeps the accounts, the roles and the sign-in page; **Google**, which only says who someone is; and **Clerk**, a hosted service.

The code on this page is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): servers kept as tests, for what the example apps do not use. The Keycloak tests run against a real Keycloak, started for the occasion.

## Keycloak

`spider g auth --provider=keycloak` generates this in a project. What it comes down to:

```zig from=examples/guide/login/server.zig decl=keycloak,run
```

- `Keycloak.init` fetches the realm's signing keys, so Keycloak has to be reachable when the app starts.
- `keycloak.middleware()` reads the token of every request and tells the routes who is there. A route that is not `.public` then needs a signed-in visitor.
- The three routes are the provider's own handlers, and they are `.public`: nobody is signed in yet when they are called.

An app takes the settings from the environment, with `spider.keycloak.KeycloakConfig.fromEnv()`: `KEYCLOAK_BASE_URL`, `KEYCLOAK_REALM`, `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET` and `KEYCLOAK_REDIRECT_URI`. The redirect address is the app's callback route, written exactly as the client in Keycloak has it.

### The round trip

The test plays the visitor, step by step:

```zig from=examples/guide/login/tests.zig decl=signIn decl="login: a visitor is sent to sign in, and comes back as themselves"
```

After it, the browser holds two cookies of the app: `__session`, the token every request is checked by (7 days), and `__refresh`, which gets a new one when it runs out (30 days). Both are `HttpOnly`, and `Secure` unless the redirect address is plain `http`, as on a developer's machine.

A handler reads who is there the same way as with any login:

```zig from=examples/guide/login/server.zig decl=me
```

### What happens without a token

- A browser asking for a page is sent to the login route.
- A token that ran out sends the browser to the refresh route, which gets a new one with the refresh cookie and comes back to the page that was asked for. A request htmx made, or a stream, gets a 401 there instead of a redirect.
- A program sends its token in an `Authorization: Bearer` header. One that is not valid is a 401:

```zig from=examples/guide/login/tests.zig decl="login: a program sends its token in a header, and a bad one is refused"
```

With `.api_mode = true` in the config, every request without a valid token gets a 401 with a JSON body, and nothing is redirected: for an app that is only an API.

### Roles

Roles are given to users in Keycloak, and a route asks for them with `.roles`:

```zig from=examples/guide/login/tests.zig decl="login: the roles given in Keycloak are the roles the routes check"
```

**Keycloak does not put roles in the token the app keeps unless it is told to.** The session cookie holds the ID token, and a new realm adds roles only to the access token: every `.roles` route then answers 403 to everyone. In the client's scopes, set the "realm roles" mapper to add the claim to the ID token. This is the realm the tests use, as Keycloak imports it; the mapper is under `protocolMappers`:

```json from=examples/guide/login/realm.json
```

The roles are read from `realm_access.roles`. For roles of one client instead of the realm, `.roles_claim = "resource_access.<client>.roles"`.

### A callback nobody asked for

The login route gives the browser a random `state` and keeps a copy in a cookie; the callback only goes on when the two match. A callback address made by hand, or sent to a visitor by someone else, has no matching cookie:

```zig from=examples/guide/login/tests.zig decl="login: a callback nobody asked for is refused"
```

So every sign-in has to start at the login route, never at an address to Keycloak written by hand. For Keycloak's registration page, or to skip its form and go straight to a login it brokers, a route calls `keycloak.authorize(c, .{ .endpoint = .registrations })` or `.{ .idp_hint = "google" }`.

### Signing out

```zig from=examples/guide/login/server.zig decl=logout
```

```zig from=examples/guide/login/tests.zig decl="login: signing out forgets the app's cookies"
```

That signs the visitor out of the app. They are still signed in at Keycloak, so the next visit to the login route brings them back without a password; to end that too, send them to the realm's own logout address.

## Google

"Sign in with Google" is smaller: there is no middleware and no cookie of Google's in the app. Google says who the visitor is, once, and the app signs them in the way it signs anyone in.

```zig from=examples/guide/src/server.zig decl=google,googleLogin,googleCallback
```

The client's id and secret come from the Google Cloud console, where the callback address is registered too.

```zig from=examples/guide/src/google_test.zig decl="google: the visitor goes to Google with a state this browser keeps"
```

In the test, Google is played by two small servers: one trades the code for a token, the other gives the profile.

```zig from=examples/guide/src/google_test.zig decl="google: back with a code, the app asks Google who it is"
```

A profile has `id` (Google's own, and the one to store: an e-mail can change), `email`, `name` and `picture`. With it the app finds or makes its account and starts its session: with accounts generated by `spider g auth`, that is `spider.session.start`, as [Login](/docs/auth) shows.

The callback fails by name: `error.OAuthStateMismatch` when the sign-in was not started in this browser, `error.OAuthCodeMissing` when the visitor said no at Google's page, and two more for a code Google refuses and for a profile it does not give. The first two are a 400:

```zig from=examples/guide/src/google_test.zig decl="google: a callback this browser did not ask for is refused before Google is asked anything"
```

## Clerk

`spider.clerk` has the shape of the Keycloak one: a value made at start, a middleware, a login route and a callback route.

It was not run for this page, because it needs a Clerk account: what follows is from its reference.

- `Clerk.init(allocator, io, .{ .publishable_key, .secret_key, .redirect_uri })`. Nothing is read from the environment. The address of the instance is taken from the publishable key, and its signing keys are fetched at start.
- `clerk.middleware()`, `clerk.loginHandler()` and `clerk.callbackHandler()`, mounted as above. The callback sets the `__session` cookie.
- There is no refresh route: a token that ran out is a 401.
- Clerk tokens carry no roles unless a custom session claim adds them: `{"roles": "{{user.public_metadata.roles}}"}` in Clerk, and `.roles_claim = "roles"` in the config. The role in the active organization, which `.org_roles` checks, is read without any setting.

## Running the Keycloak tests

They need Docker. A script starts a Keycloak with the test realm, runs the tests and removes it:

```bash from=examples/guide/login-test.sh
```

```yaml from=examples/guide/login/docker-compose.yml
```
