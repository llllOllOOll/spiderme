---
title: Routing
section: guide
order: 10
---

# Routing

A route is a method, a path, the function that answers it, and who may call it. Each feature of an app keeps its routes in one file, `routes.zig`.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)). These are all its routes:

```zig from=examples/posts/src/features/posts/routes.zig decl=build
```

`build` returns a group: routes that share a prefix. Each path is added to the prefix, so `""` is `/posts` itself and `/new` is `/posts/new`.

Every route takes three arguments: the path, the handler, and a config that says who may call it. `defaults` says it once for the whole group: `.public`, anyone. A route that names its own access replaces the default, and here the routes that write do: `.authenticated` is anyone who is signed in, and `.policy` names a rule: here, that a post is changed by who wrote it. A route with `.{}` keeps the default. [Login](/docs/auth) and [Access policies](/docs/policies) explain the rest.

## Dynamic segments

A segment that starts with a colon matches any value at that position: `/:id` answers `/posts/4` and `/posts/9`. The handler reads the value by its name with `c.params.get`. The value arrives decoded: `/tags/caf%C3%A9` gives `café`.

Posts looks up a post in one place:

```zig from=examples/posts/src/features/posts/policy.zig decl=load
```

The value is text. `load` turns it into a number, and gives null when it is not one or when no post has that id. The page of a post answers that with 404, by returning `error.NotFound`:

```zig from=examples/posts/src/features/posts/controller.zig decl=show
```

A fixed path wins over a dynamic one: `/posts/new` reaches `new`, not `show` with an id of "new". The order the routes are written in does not matter.

Instead of reading the text and converting it, a handler can ask for the value already converted, in its parameters: `id: spider.Path(u32, "id")`, read as `id.value` ([Requests](/docs/request)). A value that does not convert names nothing, so the answer is 404 before the handler runs; an enum takes its tag names, `spider.Path(enum { daily, weekly }, "period")`, and any other name is a 404 too. A route whose path has no `:id` for a handler that reads one is refused when the server starts, with a message that names the route.

## The rest of a path

A path that ends in `/*` takes everything after it, at any depth: `/files/*` answers `/files/a` and `/files/a/b/c.pdf`. The handler reads it with `c.params.get("*")`, as it was sent (`a/b%2Fc.pdf`).

## Methods

A request to a path that has routes, but none for its method, answers `405` with an `Allow` header listing the methods the path does have; a path with no route at all is a 404. `HEAD` is answered by the `GET` route: the same status and headers, without the body. A route registered for `HEAD` itself wins.

A request that declares a body is read whatever its method, so a `DELETE` with a JSON body reaches the handler with it.

## How routes reach the server

`src/main.zig` does not list routes. It mounts the features, and that registers every function of a feature's `routes.zig` that takes no parameters and returns a group:

```zig from=examples/posts/src/main.zig decl=serve
```

So a feature can have more than one group. The posts feature has three: the pages above, a JSON API under `/api/posts`, and one outside both for the address of the site itself:

```zig from=examples/posts/src/features/posts/routes.zig decl=home
```

## See what is registered

```bash
spider routes
```

It prints every route of the app with who may call it:

```text
GET     /                                                public
GET     /_spider/health                                  public  quiet_log
GET     /api/posts                                       public
POST    /api/posts                                       public
GET     /api/posts/:id                                   public
GET     /auth/account                                    authenticated
GET     /auth/login                                      public
POST    /auth/login                                      public
POST    /auth/logout                                     authenticated
GET     /auth/register                                   public
POST    /auth/register                                   public
GET     /posts                                           public
GET     /posts/:id                                       public
GET     /posts/:id/delete                                authenticated
POST    /posts/:id/delete                                authenticated
GET     /posts/:id/edit                                  authenticated
POST    /posts/:id/update                                authenticated
POST    /posts/create                                    authenticated
GET     /posts/export.csv                                public
GET     /posts/new                                       authenticated
GET     /up                                              public  quiet_log
21 routes
```

`/up` and `/_spider/health` come with Spider: they answer whether the app is running.
