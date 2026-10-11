---
title: Access policies
section: guide
order: 100
---

# Access policies

`.authenticated` and `.roles` say who may call a route. Some rules are about the thing the route works on: a post is changed by who wrote it, whoever else is signed in. That is a policy.

The code on this page is from [Posts](https://posts.spiderme.org), the example app in `examples/posts` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)). Anyone with an account writes posts there, and each account changes and deletes its own.

## The rules, in one file

A post keeps the account that wrote it, in a column:

```sql from=examples/posts/src/core/db/migrations/1791583874_posts_belong_to_users.sql
```

The rules about posts are in `src/features/posts/policy.zig`:

```zig from=examples/posts/src/features/posts/policy.zig decl=Posts,load,isAuthor,signedInId
```

`spider.policySet` takes the type the rules are about, a name, a function that loads one from the request, and the rules. A rule is a function that receives the request and the loaded post and answers yes or no. Two actions can share a rule, as `.update` and `.delete` do here.

## On a route

A route names the rule it needs:

```zig from=examples/posts/src/features/posts/routes.zig decl=build
```

Before the handler runs, Spider does this, in order:

1. Nobody signed in: 401. The post is not even loaded. In Posts that becomes a redirect to the sign-in page.
2. `load` gives null: 404.
3. The rule says no: 403.
4. The rule says yes: the handler runs.

So a handler behind a policy does not check anything, and does not load the post again. It asks for it as a parameter:

```zig from=examples/posts/src/features/posts/controller.zig decl=Mine,edit,update
```

`spider.Loaded(model.Post)` is the post the policy loaded and allowed; `.value` points at it.

## In a page

A page that anyone reads still has to decide what to offer. The same rule answers, with `can`:

```zig from=examples/posts/src/features/posts/controller.zig decl=show
```

```html from=examples/posts/src/features/posts/views/show.html
```

Hiding the buttons is a courtesy to the reader. What protects the post is the route: someone who types the address of the edit page of a post that is not theirs gets the 403.

## The 403 page

A refusal reaches the app's error handler as `error.Forbidden`. Posts gives it a page of its own, with `forbidden_view`:

```zig from=examples/posts/src/main.zig decl=onError,fallback,api_errors
```

```html from=examples/posts/src/shared/templates/forbidden.html
```

## Answering 404 instead

A 403 tells the caller that the post exists. When that is already too much (a private document, an invoice), make a refusal look like a missing page:

```zig
pub const Posts = spider.policySet(model.Post, .{
    .name = "post",
    .load = load,
    .deny = .not_found,
    .rules = .{
        .update = isAuthor,
        .delete = isAuthor,
    },
});
```

## A rule that is not about a post

`spider.policy` is for a rule with nothing to load: the function receives the request alone.

```zig
fn openToday(c: *spider.Ctx) bool {
    _ = c;
    return false;
}
```

```zig
        .get("/new", controller.new, .{ .policy = spider.policy("open_today", openToday) })
```

## In the tests

A policy shows in the access table of the feature by its name, so a route that loses its rule fails `zig build test`:

```zig from=examples/posts/src/features/posts/routes_test.zig decl="posts routes: method, path and access"
```

And the rule itself is tested by calling the app as two different accounts:

```zig from=examples/posts/src/app_test.zig decl="only the author changes or deletes a post: someone else gets 403"
```

[Testing](/docs/testing) explains `signUp`, `publish` and `app.with`.
