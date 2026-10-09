---
title: Routing
section: guide
order: 10
---

# Routing

A route is a method, a path, the function that answers it, and who may call it. Each feature of an app keeps its routes in one file, `routes.zig`.

The code on this page is from Posts, the example app in `examples/posts`. These are all its routes:

```zig from=examples/posts/src/features/posts/routes.zig decl=build
```

`build` returns a group: routes that share a prefix. Each path is added to the prefix, so `""` is `/posts` itself and `/new` is `/posts/new`.

Every route takes three arguments: the path, the handler, and a config that says who may call it. Here the config is empty because `defaults` already said it for the whole group: `.public`, anyone. A route that sets its own access replaces the default.

## Dynamic segments

A segment that starts with a colon matches any value at that position: `/:id` answers `/posts/4` and `/posts/9`. The handler reads the value by its name with `c.params.get`.

Posts looks up a post in one place, and every handler that needs one calls it:

```zig from=examples/posts/src/features/posts/controller.zig decl=load,show
```

The value is text. `load` turns it into a number, and answers 404, by returning `error.NotFound`, when it is not one or when no post has that id.

A fixed path wins over a dynamic one: `/posts/new` reaches `new`, not `show` with an id of "new". The order the routes are written in does not matter.

## How routes reach the server

`src/main.zig` does not list routes. It mounts the features, and that registers every function of a feature's `routes.zig` that takes no parameters and returns a group:

```zig from=examples/posts/src/main.zig decl=serve
```

So a feature can have more than one group. Posts has a second one, outside `/posts`, for the address of the site itself:

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
GET     /posts                                           public
GET     /posts/:id                                       public
GET     /posts/:id/delete                                public
POST    /posts/:id/delete                                public
GET     /posts/:id/edit                                  public
POST    /posts/:id/update                                public
POST    /posts/create                                    public
GET     /posts/new                                       public
GET     /up                                              public  quiet_log
11 routes
```

`/up` and `/_spider/health` come with Spider: they answer whether the app is running.
