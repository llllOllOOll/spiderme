-- doc

# Static Files#

Spider serves static files automatically from the `./public/` directory. No configuration needed.

## Basic Usage#

```
public/css/app.css    → GET /css/app.css
public/logo.png       → GET /logo.png
public/js/main.js      → GET /js/main.js
```

Path traversal (`../../etc/passwd`) is blocked automatically. URL-encoded traversal (`%2e%2e`) is blocked by Zig's HTTP stack before reaching Spider.

## Custom Static Directory#

```zig
var server = spider.app();
server.staticDir("./assets");  // serves from ./assets/ at /
```

## Custom Prefix#

```zig
server.staticAt("./public", "/static/");  // serves from ./public/ at /static/
```

## Route-specific#

```zig
server.get("/assets/*", spider.static.serve);  // manual route
```

## With Tailwind CSS#

SpiderStack uses Tailwind CSS with DaisyUI. Setup:

### Install#

```bash
pnpm init
pnpm add -D tailwindcss postcss autoprefixer daisyui
npx tailwindcss init -p
```

### tailwind.config.js#

```javascript
module.exports = {
    content: [
        "./src/**/*.{zig,html}",   // scan Zig and HTML files
    ],
    theme: {
        extend: {},
    },
    plugins: [
        require('daisyui'),
    ],
}
```

### Build#

```bash
pnpm run build:css      # one-time build
pnpm run watch:css      # watch mode during development
```

CSS output goes to `public/css/app.css` and is served automatically.
