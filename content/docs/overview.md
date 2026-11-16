---
title: Overview
section: start
order: 5
---

# Web apps in Zig, *one binary* to ship.

Spider is a web framework for Zig: a router, templates checked when the app compiles, PostgreSQL, SQLite and SQL Server, and a command line tool that writes the project for you.

```bash
curl -fsSL https://spiderme.org/install.sh | bash
```

**942 KB**, the release build of a new project · **Zig 0.17.0**, and nothing else to install · **Linux, macOS and Windows**

## The guide, in order

Five steps from nothing to a running app. Each one is a page.

1. [Install](/docs/quickstart#Install-the-command-line-tool) Zig 0.17.0 and the spider tool. `spider version`
2. [Create an app](/docs/quickstart#Create-an-app) HTML views and SQLite, rebuilt as you save. `spider new myapp`
3. [Add a feature](/docs/quickstart#Add-a-feature) Its routes, controller, views and migration. `spider g feature posts`
4. [Add a login](/docs/auth) Accounts, and every route says who may call it. `spider g auth`
5. [Ship it](/docs/docker) A release build, its debug file, a Docker image. `docker build .`

## The code and the page it makes

The feed of the Posts example: its handler, and the page at [posts.spiderme.org](https://posts.spiderme.org). `c.viewChecked` checks the view against the data when the app compiles: a field the template reads and the handler does not send is a build error, not a blank on the page.

```zig from=examples/posts/src/features/posts/controller.zig decl=index
```

![The feed of the Posts example, posts.spiderme.org](/images/posts-feed.png)

## Apps to read

The guides quote these apps. They run on spiderme.org, and their source is next to the docs.

- [Posts](https://posts.spiderme.org) Accounts, posts owned by their authors, a JSON API with a key. ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/posts)) `SQLite`
- [Bookings](https://bookings.spiderme.org) Rooms booked by the half hour, a day view that updates live, mail and a webhook. ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/bookings)) `PostgreSQL`
- [Pixels](https://pixels.spiderme.org) A 48x48 board everyone paints at once, and a QR code to join from a phone. ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/pixels)) `WebSocket`
