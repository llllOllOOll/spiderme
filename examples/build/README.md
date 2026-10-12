# Build example

Not an app to deploy: what `content/docs/build.md` says about a project's
build, kept as tests so that the page cannot say what stopped being true.

    zig build test

- `build.zig` asks Spider for one optional part (`.qrcode = true`) and
  builds the app in `src/main.zig` twice: templates in the binary, and
  templates read from disk.
- The first runs from `elsewhere/`, a directory with no templates, and
  answers. The second answers from here, and from `elsewhere/` has no page
  to give.
- `src/ticket.zig` uses the part that was asked for. `src/sheet.zig` uses
  one that was not: it must fail to compile, and the build checks that it
  does.

The site's own `zig build test` runs these too.
