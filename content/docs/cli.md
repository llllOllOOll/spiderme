---
title: Command line tool
section: reference
order: 5
---

# Command line tool

`spider` creates a project, runs it while you work, and generates code inside it. This page goes through every command, with what it prints.

```text
spider new <name>        create a project
spider dev               build, run, reload after every save
spider g feature <name>  generate a feature
spider g auth            add a login
spider migrate           apply the migrations
spider routes            list the routes and who may call them
spider check             check the project's conventions
spider install           download the frontend assets
spider ui                show or switch the UI kit
spider icons             show, add or remove icon sets
spider add pwa           make the app installable
spider remove pwa        undo that
spider generate-vapid    make the keys for Web Push
spider update            move the project to the latest Spider
spider self-update       update the tool itself
spider version           the version installed
```

Every command explains itself: `spider help new`, or `spider new --help`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/llllOllOOll/spider/main/scripts/install.sh | bash
```

`spider version` prints the version installed:

```text
spider v0.10.0
```

`spider self-update` downloads and installs the latest one.

## spider new

```bash
spider new myapp
```

It writes the project to `./myapp`, one line per file, fetches Spider, and says what to do next:

```text
  create  myapp/src/features/home/controller.zig
  create  myapp/src/features/home/routes.zig
  create  myapp/src/features/home/routes_test.zig
  create  myapp/Dockerfile
  create  myapp/.env.example
  create  myapp/.gitignore
  create  myapp/src/app_test.zig
  create  myapp/src/ui.css (UI kit: daisyui)
  create  myapp/.env (local settings, git-ignored; JWT_SECRET generated)
Fetching Spider v0.10.0...

Done! Next steps:
  cd myapp
  spider dev           ← builds, runs, and reloads the browser as you edit
```

Without options the project has HTML views, a SQLite database and a first test. The options change that:

- `--pg` uses PostgreSQL instead of SQLite.
- `--no-db` leaves the database out.
- `--api` makes a JSON project, without HTML views.
- `--ui=tailwind` uses plain Tailwind instead of daisyUI. `spider ui use` switches later.
- `--pwa` makes the app installable. It is the same as running `spider add pwa` afterwards.
- `--skip-downloads` does not download Tailwind, Alpine, htmx and the icons now. `spider install` does it later.

What the project has:

```text
build.zig  build.zig.zon     the build, and Spider as a dependency
spider.config.zig            settings that are the same everywhere
.env  .env.example           settings of this machine; .env stays out of git
Dockerfile
src/main.zig                 starts the server
src/app_test.zig             tests that call the running app
src/features/                one folder per feature; home/ is the first
src/features/mod.zig         the list of features the server mounts
src/core/db/                 the database and its migrations
src/shared/templates/        the layout and what every page shares
src/styles.css  src/ui.css   the styles, and the classes of the UI kit
public/                      files served as they are
```

## spider dev

Run it inside the project.

```bash
spider dev
```

It builds the app, runs it, and after every save builds it again and reloads the browser. While a build runs or after it fails, the version that was up keeps answering, and the compiler's errors go to the terminal. Ctrl+C stops it.

`--port 4000` makes the app listen on another port for this run. [Development](/docs/development) has more on working this way.

## spider g feature

```bash
spider g feature notes
```

A feature is a folder with everything one part of the app needs. The command writes it, with pages to list, create, edit and delete:

```text
  create  src/features/notes/model.zig
  create  src/features/notes/repository.zig
  create  src/features/notes/controller.zig
  create  src/features/notes/routes.zig
  create  src/features/notes/routes_test.zig
  create  src/features/notes/views/index.html
  create  src/features/notes/views/NotesList.html
  create  src/features/notes/views/NotesCard.html
  create  src/features/notes/views/NotesForm.html
  create  src/features/notes/views/NotesEditForm.html
  create  src/features/notes/views/page.html
  create  src/core/db/migrations/1791665601_create_notes.sql
  update  src/core/db/migrations.zig
  update  src/features/mod.zig
  (routes mounted by mountFeatures in src/main.zig)

Done! Next:
  spider migrate   create the notes table (until then /notes answers 500)
  spider routes    check what got registered, and who may call it
  access: src/features/notes/routes.zig (defaults() and each route's config)
```

Nothing in `src/main.zig` changes: the server mounts every feature listed in `src/features/mod.zig`, and the command adds the new one there.

`--api` generates JSON routes instead of pages.

The feature starts with one column, `name`. Add yours to the migration, to the struct in `model.zig` and to the forms.

## spider g auth

```bash
spider g auth
```

It adds a login with the app's own accounts: a `users` table, pages to sign up, sign in and sign out, and their tests.

```text
Generating login with the app's own users...
  create  src/features/auth/mod.zig
  create  src/features/auth/model.zig
  create  src/features/auth/repository.zig
  create  src/features/auth/controller.zig
  create  src/features/auth/routes.zig
  create  src/features/auth/routes_test.zig
  create  src/features/auth/views/login.html
  create  src/features/auth/views/register.html
  create  src/features/auth/views/account.html
  update  src/features/mod.zig
  create  src/core/db/migrations/1791665601_create_users.sql
  update  src/core/db/migrations.zig
  update  src/main.zig (session middleware)
  update  src/app_test.zig (tests of the login)

Done. Open /auth/register to create the first account.

  Every route that is not `.public` now needs a login. Features made before
  this have their access undeclared: `spider check` lists them.
```

- `--api` generates JSON routes that answer a token, without pages.
- `--provider=keycloak` generates a login through a Keycloak realm instead.

[Authentication](/docs/auth) explains what was generated and how to use it.

## spider migrate

A migration is a file in `src/core/db/migrations/`, named with a number and what it does. It has two parts: what to apply, and how to undo it.

```sql
-- migrate:up
CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    inserted_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- migrate:down
DROP TABLE IF EXISTS notes;
```

`spider migrate` applies the `up` part of each one that has not run yet, in order:

```text
Running migrations on SQLite: db.sqlite...
  running  1791665601_create_notes
  applied  1791665601_create_notes
  running  1791665601_create_users
  applied  1791665601_create_users

2 migration(s) applied.
```

Run it again and there is nothing to do:

```text
Running migrations on SQLite: db.sqlite...
Nothing to migrate.
```

It reads where the database is from `.env`: `SQLITE_PATH` for SQLite, `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD` and `PG_DB` for PostgreSQL. The app applies pending migrations when it starts too, so the command is for when you want them applied without running the app. [Database](/docs/database) is about writing them.

## spider routes

```bash
spider routes
```

It builds the app, starts it up to the point where it would listen, and prints every route: the method, the path, and who may call it.

```text
GET     /                                                public
GET     /_spider/health                                  public  quiet_log
GET     /auth/account                                    authenticated
GET     /auth/login                                      public
POST    /auth/login                                      public
POST    /auth/logout                                     authenticated
GET     /auth/register                                   public
POST    /auth/register                                   public
GET     /notes                                           -
POST    /notes/:id/delete                                -
GET     /notes/:id/edit                                  -
POST    /notes/:id/update                                -
POST    /notes/create                                    -
GET     /notes/new                                       -
GET     /up                                              public  quiet_log
15 routes
```

The third column is the access the route declares: `public`, `authenticated`, `roles:`, `org:`, `policy:`, or `-` when it declares none. In an app with a login, `-` means any signed-in visitor may call it.

`--check` is for that case. It fails when the app has a login and a route declares nothing:

```text
6 route(s) declare no access; with auth, any logged-in user may call them:
  GET /notes
  POST /notes/:id/delete
  GET /notes/:id/edit
  POST /notes/:id/update
  POST /notes/create
  GET /notes/new
fix: .roles / .org_roles / .authenticated / .policy / .public in the route's config, or defaults() in its group
```

`--lock` writes the listing to `routes.lock`. Commit it.

```text
wrote routes.lock (15 routes)
```

`--diff` compares the app with that file and fails when they differ, so a change of access shows up in review and in CI:

```text
routes differ from routes.lock:
- GET /notes/new -
+ GET /notes/new authenticated
if intended, review and update it: spider routes --lock
```

`--json` prints the listing as one line of JSON.

## spider check

```bash
spider check
```

It reads the project and reports what does not follow its conventions, each with the file, the line and the fix:

```text
src/features/notes/routes.zig:21: error [route-access]: route declares no access; with auth, any logged-in user may call it
    fix: add .roles / .org_roles / .authenticated (any logged-in user) / .policy or .public to its config, or a defaults(...) to its group
6 error(s), 0 warning(s)
```

What it treats as an error:

- a route registered outside a feature's `routes.zig`;
- a class of the UI kit (`btn`, `card`) written in a template instead of its `ui-` class;
- an icon class of a set that `src/styles.css` does not load;
- a feature that is not in `src/features/mod.zig`;
- in an app with a login, a route that declares no access.

And as a warning: an inline `style=`, a pasted `<svg>`, a feature without `routes_test.zig`. `--strict` fails on warnings too, which is what you want in CI.

A new project runs the same checks in `zig build test`, so they also fail there. [Testing](/docs/testing) shows that.

## spider install

```bash
spider install
```

It downloads the frontend assets into the project: Tailwind, Alpine, htmx, daisyUI when the UI kit uses it, and the icon sets that `src/styles.css` loads. A new project has them already. They are not committed to git, so run it after cloning a project.

## spider ui

Templates use classes that start with `ui-` (`ui-btn`, `ui-input`, `ui-card`). `src/ui.css` says what each one means, and it is the only file that knows which UI kit the app uses.

`spider ui` shows the kit in use and the ones available:

```text
UI kit: daisyui   (src/ui.css)

Kits:
  daisyui   daisyUI 5 components and themes (bin/daisyui.mjs)
  tailwind  plain Tailwind, no component library

Switch: spider ui use <kit>
```

`spider ui use tailwind` rewrites `src/ui.css` for that kit and lists the template lines that still use the old kit's classes directly. It refuses when you have edited `src/ui.css`, unless you add `--force`.

## spider icons

An icon is a class: `<span class="hero-home size-5"></span>`. `spider icons` shows the sets the app loads:

```text
Icon sets in this app (src/styles.css):
  heroicons  hero-*   e.g. hero-home, hero-home-solid, hero-home-mini, hero-home-micro

Available: heroicons, lucide, tabler
Add or remove one: spider icons add <set> / spider icons remove <set>
```

`spider icons add lucide` adds the set to `src/styles.css` and downloads it. `spider icons remove lucide` takes it out and lists the template lines that still use its classes.

## spider add pwa

```bash
spider add pwa
```

It makes the app installable on a phone or a desktop: a manifest, a service worker that shows a page when the device is offline, the script that registers it, and the icons.

```text
  create  public/pwa/icon-192.png
  create  public/pwa/icon-512.png
  create  public/pwa/icon-maskable-512.png
  create  public/pwa/apple-touch-icon.png
  update  src/shared/templates/layout.html (<head>: manifest, theme-color, pwa.js)
  update  src/shared/templates/app.html (<head>: manifest, theme-color, pwa.js)

PWA added. Check it in Chrome DevTools > Application > Manifest / Service workers.
 - Replace public/pwa/*.png with your icons (the maskable one keeps the logo
   inside the center 80%), and set name/colors in public/manifest.webmanifest.
 - Install button: <button x-show="$store.pwa.canInstall" @click="$store.pwa.install()">Install</button>
 - Service workers need HTTPS (localhost is exempt).
```

The service worker never keeps pages or API answers: what the visitor sees is always what the server sent.

`spider remove pwa` undoes it. It deletes the manifest, the offline page, the script and the icons, and replaces `public/sw.js` with one that removes itself from the browsers that installed the app:

```text
  update  public/sw.js (unregisters itself in browsers that installed the app)
  delete  public/manifest.webmanifest
  delete  public/offline.html
  delete  public/js/pwa.js
  delete  public/pwa/
  update  src/shared/templates/layout.html (removed the PWA <head> block)
  update  src/shared/templates/app.html (removed the PWA <head> block)

Keep public/sw.js for a few weeks — until your users have visited again —
then delete it.
```

## spider generate-vapid

Web Push needs a pair of keys that identifies the app to the push services. This makes one:

```bash
spider generate-vapid mailto:ops@example.com
```

```text
VAPID keys generated successfully!

Add these to your .env file:

VAPID_SUBJECT=mailto:ops@example.com
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...
```

The argument is how a push service can reach you: a `mailto:` or an `https:` address. Generate the pair once and keep it. Subscriptions are tied to the public key, so a new pair loses every subscriber.

## spider update

`spider update` moves the project to the latest Spider. It changes `build.zig.zon`, so read the [changelog](https://github.com/llllOllOOll/spider/blob/main/CHANGELOG.md) before you run it: a release may change what the app has to do.
