# French learning app

An iOS app for learning French from numbered lessons. Interface text is Russian, study
material is French, code and docs are English.

Stack: SwiftUI, iOS 26, Liquid Glass. Built only in GitHub Actions (`macos-26`) into an unsigned
IPA that the owner signs and sideloads with ESign. There is no Mac and no Apple developer account.

## Layout

- `App/`: the SwiftUI app. `Model/` owns state (`Library` bundled content, `Store` learner data,
  `Speech`), `Views/` the screens. `project.yml` (XcodeGen) is the project; `.xcodeproj` is never committed.
- `Core/`: Swift package `FrenchCore`, Foundation only. All logic that can be tested without UI.
- `UITests/`: walks every screen and attaches screenshots; they are how the UI gets reviewed.
- `tools/`: Node scripts, no dependencies, that turn the lesson vault and Lexique into
  `App/Resources/` (`content.json`, `lexicon.tsv`, `lemmas.tsv`, `examples.tsv`). The outputs are committed.
- `prototype/`: clickable HTML design. The app follows its look and interaction.
- `docs/SPEC.md`: what the app does, the decisions taken, where it departs from the prototype.

## Rules

- The app may use no entitlements, extensions or embedded frameworks: the IPA must stay signable
  by any certificate. CI checks the IPA for this.
- Learner data is one JSON file (`UserData`), and it is the backup format. A change to it must
  still decode older files (new fields optional) and bump `UserData.currentVersion` only when it cannot.
- `Core/` imports no SwiftUI or UIKit. New logic goes there with a test.
- Reading rules are data (`readingRules[].pattern` in `content.json`), applied by
  `applies()` in `tools/import-vault.mjs` and by `ReadingPattern.applies` in Core. A new kind of
  rule goes into both, and `BundledDataTests` checks they still agree.
- Never hand-edit `App/Resources/*`; change `tools/` and regenerate. The lesson vault lives outside
  the repo; only lessons whose `Дашборд.md` has `lesson: N` front matter are imported.
- `prototype/data.js` is hand-written sample content and the acceptance test of `tools/align.mjs`.
  Correct mistakes in it, do not regenerate it. Known notation differences are listed in
  `tools/align.test.mjs`.
- French strings use one pronunciation markup everywhere: `(x)` silent letters, `[x]` nasal
  vowel, `{x}` consonant heard only in a liaison, `‿` liaison between words. Text that has no marks
  is shown as written and never parsed: it may contain brackets of its own.
- Change `prototype/` only when the design changes, and update `docs/SPEC.md` in the same change.
  Its scripts are classic scripts sharing one global scope, loaded in the order in `index.html`.
- Commits carry no co-author or tool attribution lines (owner's request).

## Commands

- Regenerate content: `node tools/import-vault.mjs <vault dir>`, then `node tools/build-lexicon.mjs`
  and `node tools/build-examples.mjs` (they download Lexique and Tatoeba to `.cache/` on first run;
  Tatoeba needs `bunzip2`).
- Tool tests: `node --test tools/*.test.mjs`
- Core build and tests on this machine: Swift from nixpkgs, run inside
  `nix develop --impure --expr '<mkShell with swift, swiftpm, swiftPackages.{Foundation,XCTest,Dispatch}, LD_LIBRARY_PATH=Dispatch/lib>'`.
  `swift build` works; `swift test` does not (libIndexStore is missing from nixpkgs), so tests run in CI.
- App build, UI tests, IPA: push to `main`, then `gh run watch`, and
  `gh run download <id> --name screenshots` for the screenshots.
- Prototype: open `prototype/index.html`; a hash jumps to a screen (`index.html#card`).
  Visual check without Chromium: `zen-beta --headless --no-remote --profile <scratch dir>
  --window-size=393,852 --screenshot out.png <file url>`.
- Publish the prototype: strip the document tags from `prototype/index.html` into a scratch copy
  (`sed -e '1,/<!-- page/d' -e '/<\/body>/,$d'`) and publish that copy as the page of
  https://claude.ai/artifact/CV43veJEnAwrL2BELWaxZ2, with the CSS and JS files as supporting files.
