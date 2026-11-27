---
title: Versions
section: start
order: 30
---

# Versions

You pick the Spider an app uses, and it stays there until you move it. A published version is there for good.

## Two channels

| Channel | What it is | In an app's `build.zig.zon` |
|---|---|---|
| **Stable** | the releases: tags `vX.Y.Z`, never moved | `?ref=v0.12.1` and that tag's commit |
| **Development** | the `develop` branch, the next release: today `0.14.0-dev` | `?ref=develop` and the commit it stood at when it was fetched |

A project on `develop` is pinned to one commit too: it does not move when `develop` does. It moves when you move it.

There is no 0.13: the release after 0.12 is 0.14.

## What a version number promises

Versions read as semver before 1.0:

- A minor (`0.12` to `0.14`) may break an app. The [changelog](https://github.com/llllOllOOll/spider/blob/develop/CHANGELOG.md) says how to move, under **Breaking changes**.
- A patch (`0.12.1` to `0.12.2`) only fixes. A released line that needs a fix gets a patch, so its users do not have to move up for it.

## Moving a project

From the project's directory:

```bash
spider update            # the latest release
spider update 0.12.1     # that release (checked to exist first)
spider update --patch    # the latest patch of the project's line (0.12.x)
spider update --canary   # the develop branch, at its latest commit
```

Each rewrites the two lines of `build.zig.zon` ([The build](/docs/build)). Then build and run the tests: the build points at what the new version wants changed.

## The command line tool

```bash
spider self-update            # the latest release
spider self-update 0.12.1     # that release
spider self-update --canary   # a build of develop (needs git and zig)
spider self-update --stable   # back to the latest release
```

`spider self-update` with nothing after it goes to the latest release: on `develop`, keep using `--canary`.

To install the tool from `develop` on a machine that has none:

```bash
curl -fsSL https://spiderme.org/install.sh | bash -s -- --version canary
```

In a project pinned to another release, `spider` installs that release's tool once, into `~/.cache/spider/cli/X.Y.Z`, and runs it, so the code it writes fits the project. On a branch, a commit or a local path it warns instead. `SPIDER_DISPATCH=0` turns that off. `spider new` starts a project on the tool's own release, or on `develop` for a `-dev` tool.

## Zig

| Spider | Zig |
|---|---|
| 0.8.0 to 0.12.1, 0.14.0-dev | 0.17.0 |
| up to 0.7.0 | 0.17.0 development builds |

## Moving from 0.12 to 0.14

What may need a line in an app:

- **`c.view` checks the template against the data when the app compiles.** The build needs the list of templates: `@import("spider").addTemplates(b, spider_dep, "src");` in `build.zig`, in place of running `generate-templates` and of `pub const spider_templates` in `src/main.zig` (both still work). A missing template, a field the data does not have, a call to a component that does not exist, or a call that does not fit the component's `-- props:` line is a build error, with the file and the line ([Templates](/docs/templates#Checked-when-the-app-compiles)). A view whose name is chosen while the app runs becomes an `inline` switch over the names. `c.viewChecked`, its name in earlier 0.14 builds, stays for one release.
- **`c.viewFragment` is checked the same way**, as what a call `<Name />` would see: the page and the component are known when the app compiles.
- **A component with a `-- props:` line sees only its props** (and `current_user`); what is inside its tag still sees the page. A declared prop the call leaves out is taken from the caller's value of that name, so declaring every name a component reads keeps it working ([Components](/docs/components#The-props-a-component-declares)). A component without the line is unchanged, and `spider check` warns about it.
- A path value that is not of its `spider.Path` type (`/books/banana` for `spider.Path(u32, "id")`) answers **404**, not 400: it names nothing.
- A route whose path lacks a `:name` its handler reads with `spider.Path` is **refused at startup**, with a message that names the route. It used to answer 400 on every request.
- A component prop's default applies only when neither the call nor the caller's data has the value. It used to win over the caller's value.
- The I/O backend is now `.zio` by default. An app that sets `.io_backend = .threaded` keeps it ([The build](/docs/build#The-I-O-backend)).

New, and for an app to take up when it wants: [compiled templates](/docs/templates#Compiled-templates) in release builds, the [`-- props:` line](/docs/components#The-props-a-component-declares) of components, a [layout per route or group](/docs/templates#A-layout-without-extends), `installApp` in `build.zig` with the [debug info in its own file](/docs/build#The-debug-info-in-a-file-of-its-own), [SQL Server](/docs/sqlserver), and a job that [takes an `std.Io`](/docs/jobs#A-job). New projects are on [htmx 4](/docs/htmx#Which-htmx) (`--htmx=2` for htmx 2), and `spider new --minimal` makes the [smallest one](/docs/cli#spider-new).
