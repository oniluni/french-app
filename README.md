# Français

An iPhone app for learning French from numbered lessons. The interface is Russian, the study
material is French. Native SwiftUI with Liquid Glass, iOS 26 or later.

- **Lessons.** Each lesson has its text, its rules and its words. Every French word shows its
  pronunciation: silent letters faded with a dotted underline, nasal vowels on an ochre underlay,
  liaisons as an arc, IPA under the word. Tap a word, or hold and sweep over a phrase, to see its
  sound and translation, hear it, open the rule that explains it, add it to the cards, open its
  forms or write a note.
- **Practice.** Anki-style cards (SM-2, grades «Снова · Трудно · Хорошо · Легко») over a range of
  lessons saved as a set, and drills of conjugation, gender and number.
- **Analysis.** A reader that marks up any French phrase, and a word analysis that turns any form
  (`buvons`, `petites`) into its lemma and the table of all its forms.
- **Dictionary.** Every word of the lessons, searchable in French and Russian.

Everything works offline. Progress lives on the phone only.

## Install

There is no App Store build. Every push to `main` builds an **unsigned** IPA in GitHub Actions:

<https://github.com/oniluni/french-app/releases/latest/download/French.ipa>

Sign and install it with ESign or any other sideloading tool, with your own certificate.

- The app needs no entitlements, so any certificate and provisioning profile can sign it.
- To update, sign the new IPA with **the same certificate** and install it over the old app.
  The bundle id is `io.github.oniluni.french`; keep it when signing.
- If the certificate changes to one of another team, iOS refuses to install over the old app and
  it has to be deleted first, which deletes its progress too. **Before that, save a copy:**
  «Уроки» → «Данные» → «Сохранить копию в Файлы». After reinstalling, restore it with
  «Восстановить из копии».
- If Apple revokes the certificate, the app stops opening until it is signed again.
- Speech uses the French system voice. If there is none, add it in Settings → Accessibility →
  Spoken Content → Voices → French.

## Build

There is no Mac in this project. `project.yml` describes the Xcode project for
[XcodeGen](https://github.com/yonaskolb/XcodeGen); CI generates the project, runs the tests and
packs the IPA (`.github/workflows/build.yml`). The UI tests attach a screenshot of every screen to
the `screenshots` artifact of each run.

| Path | What |
|---|---|
| `App/` | SwiftUI app: screens, theme, storage, speech |
| `Core/` | `FrenchCore` Swift package: content model, pronunciation markup, scheduler, dictionary lookup, reader, paradigms, drills. Foundation only |
| `UITests/` | Walk through every screen with screenshots |
| `tools/` | Node scripts that build the bundled content from the lesson vault |
| `prototype/` | The clickable HTML design the app follows |
| `docs/SPEC.md` | What the app does and why |

Content is generated, then committed, because CI has no access to the lesson vault:

```sh
node tools/import-vault.mjs <path to french-vault>   # → App/Resources/content.json
node tools/build-lexicon.mjs                         # → App/Resources/lexicon.tsv, lemmas.tsv
node --test tools/*.test.mjs
```

## Licences

The word form dictionary (`App/Resources/lexicon.tsv`, `lemmas.tsv`) is derived from
[Lexique 3.83](http://www.lexique.org) by Boris New and Christophe Pallier, licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/); the derived files are shared
under the same licence. The lesson texts, vocabulary and rules come from a French textbook through
the owner's study notes.
