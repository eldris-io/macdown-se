# GitHub Style Generator

Generates the bundled GitHub style using Dart Sass, which runs on Apple Silicon
and Intel without a native Node Sass extension. Use Node.js 22 or later.

```sh
npm ci
make
```

To update the upstream style, run `npm update primer-markdown` and rebuild.
The Makefile fails if compilation fails and replaces the output only after
successful generation, so a missing compiler cannot silently ship empty CSS.
