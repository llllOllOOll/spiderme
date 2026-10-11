# Guide examples

Not an app: the code the guides of spiderme.org show for what neither
example app (`../posts`, `../bookings`) uses, kept here as tests so that a
page cannot show code that stopped working.

    zig build test

`src/server.zig` is one small server with a route or two per subject; each
`src/*_test.zig` asks it the way a browser or another program would. The
site's own `zig build test` runs these too.
