# French learning app

An iOS app for learning French from numbered lessons. Interface text is Russian, study
material is French, code and docs are English.

Status: design prototype only. The app itself is not started.

## Layout

- `prototype/`: clickable HTML mock of the whole app. Plain HTML, CSS and JS; no build, no
  dependencies. It is the design source of truth.
- `docs/SPEC.md`: what the prototype shows, what it fakes, open decisions, build order.

## Rules

- The stack for the real app is undecided (`docs/SPEC.md`, "Open decisions"). Do not scaffold
  an app until the owner has chosen one.
- Change `prototype/` only when the design changes, and update `docs/SPEC.md` in the same change.
- `prototype/data.js` is hand-written sample content. Its transcriptions and word forms are
  test fixtures for the real engines; correct mistakes in them, do not regenerate them.
- French strings use one pronunciation markup everywhere: `(x)` silent letters, `[x]` nasal
  vowel, `{x}` consonant heard only in a liaison, `‿` liaison between words.
- The prototype's scripts are classic scripts sharing one global scope, loaded in the order
  listed in `index.html`. ES modules do not load from `file://`.

## Commands

- Open the prototype: `prototype/index.html` in a browser. A hash jumps to a screen, for
  example `index.html#card`.
- Syntax check: `for f in prototype/*.js; do node --check "$f"; done`
- Visual check: this machine has no Chromium, so the Playwright MCP cannot start. Use
  `zen-beta --headless --no-remote --profile <scratch dir> --window-size=393,852 --screenshot out.png <file url>`.
- Publish the prototype: strip the document tags from `prototype/index.html` into a scratch copy
  (`sed -e '1,/<!-- page/d' -e '/<\/body>/,$d'`) and publish that copy as the page of
  https://claude.ai/artifact/CV43veJEnAwrL2BELWaxZ2, with the CSS and JS files as supporting files.
