# French learning app: product spec

Derived from the clickable prototype in `prototype/`. It tells whoever builds the real app
what the prototype shows, which parts of it are fake, and what is still undecided.

Interface text is Russian, study material is French. Screen and button names below are quoted
as they appear in the UI.

## 1. Source of truth

- `prototype/index.html` opens straight from disk; no server, no build, no dependencies.
- Published copy: https://claude.ai/artifact/CV43veJEnAwrL2BELWaxZ2 (private to the owner).
- A side rail (desktop width only) jumps to each screen. The same jumps work as URL hashes:
  `#lessons #text #notes #rule #sets #card #drill #reader #word #dict`.

| File | What it demonstrates |
|---|---|
| `styles.css` | Design tokens (`:root`), light and dark theme, every component |
| `data.js` | Sample content and the content shapes (lessons, words, texts, rules, paradigms, notes) |
| `pronunciation.js` | Pronunciation markup, annotated text, word and phrase selection, popover |
| `lessons.js` | Lesson list, lesson screen, rule page, notes |
| `practice.js` | Lesson-range sets, card session, list of form drills |
| `forms.js` | Form lookup, word analysis, drill session |
| `tools.js` | Reader and word-analysis tools |
| `dictionary.js` | Search tab |
| `app.js` | Navigation, overlays, shared screen parts |

Where this spec and the prototype disagree: the prototype wins on look and interaction,
this spec wins on what has to be real (section 6).

## 2. Navigation

A floating tab bar with three tabs and a separate round search button, as in iOS 26:

| Tab | Root screen | Pushed screens |
|---|---|---|
| «Уроки» | Lesson list | Lesson (`Текст · Правила · Слова`), rule, word analysis |
| «Практика» | `Слова · Формы` | Card session, drill session (both full screen, tab bar hidden) |
| «Разбор» | `Читалка · Слово` | Rule, word analysis |
| Search («Словарь») | Word list | Word analysis |

- Each tab keeps its own navigation stack. Tapping the active tab returns to its root.
- Opening search collapses the tab capsule to one round button (the tab you came from) and
  shows the search field in its place.

## 3. Screens

### 3.1 «Уроки»
- «Продолжить» card: the lesson in progress, its topic and progress.
- A row with the number of cards due today; opens «Практика».
- All lessons: number inside a progress ring, French title, Russian topic, word count.

### 3.2 Lesson
Segments `Текст · Правила · Слова`.

**Текст**
- French text in a serif face. «Прослушать текст» reads the whole text aloud.
- Tap a word, or select a phrase, to open the transcription popover (3.3).
  Phrase selection: press and drag with a mouse; on touch, hold about 280 ms and then drag,
  so that a plain vertical swipe still scrolls.
- The `[ə]` button in the navigation bar turns the pronunciation layer on and off (section 4).
  The setting is global, not per lesson.
- Fragments that have a note are underlined.
- A small round notes button sits in the bottom right corner with a count badge (3.5).

**Правила**: list of the lesson's rules (kind, title, one-line summary) leading to 3.4.

**Слова**: «Учить слова урока» starts a card session for this lesson; below it the word list
(French, translation, transcription, card status). A word opens its analysis (3.9).

### 3.3 Transcription popover
Appears under the selection, or above it when there is no room below. Closes on outside tap,
on scroll and on Escape.

- The word or phrase with pronunciation marks, its IPA, and a listen button.
- One word: its gloss. A phrase: the translation of every sentence the selection touches,
  labelled «Перевод предложения».
- One word that has a reading rule: a row «Почему так читается» linking to that rule.
- Actions, each shown only when it applies:
  - «В карточки» adds the word to the lesson's cards; «В словаре» (disabled) if it is already there.
  - «Разбор» if the form belongs to a known paradigm; opens word analysis with that form highlighted.
  - «Заметка» opens the notes sheet with the fragment quoted (lesson texts only).

### 3.4 Rule
Kind tag («Чтение» or «Грамматика»), title, prose, an optional table, examples. Tapping an
example speaks it. Table cells and examples use the pronunciation marks. Has the notes button.

### 3.5 Notes
A bottom sheet per lesson text and per rule.
- List of notes; a note may quote the text fragment it is attached to.
- Text field and «Сохранить», disabled while the field is empty.
- Saving updates the badge on the notes button and the underline in the text.
- Not designed yet: editing and deleting a note, one list of all notes across lessons.

### 3.6 «Практика» → «Слова»
- «Сегодня»: number of cards due and «Повторить» (disabled at zero).
- «Новый набор»: a grid of lesson numbers. The first tap sets the start, the second the end;
  a third tap starts over. The summary shows the range and its word count. «Начать» saves the
  range as a set and starts a session. One tap then «Начать» is a single-lesson set.
- «Мои наборы»: saved ranges with a progress ring, learned count and due count. Tapping one
  starts a session. Saved sets are how the learner returns to a range.

**Card session** (full screen)
- Close button, set title, `done / total` counter, progress bar.
- Front: the French word without marks and a hint. Listen button in the card corner.
- Tap the card or «Показать ответ» to flip. Back: the word with marks, IPA, translation.
- Four grades with the next interval under each: «Снова», «Трудно», «Хорошо», «Легко».
  «Снова» puts the card back at the end of the queue.
- A session holds at most 10 cards, taken in this order: due, new, learning, known.
- End screen: counts per grade, when the next review is, «Готово».

### 3.7 «Практика» → «Формы»
- «Смешанная тренировка»: 8 questions across all paradigms.
- «Спряжения»: tense filter chips and a list of verbs. A verb starts a drill on that verb,
  limited to the chosen tense if one is selected.
- «Род и число»: adjectives and nouns; each starts a drill on that word.

**Drill session** (full screen, same frame as the card session)
- Verb question: pronoun plus a blank, the person in Russian, four answer options. Options are
  verb forms without the pronoun, otherwise the pronoun gives the answer away.
- Noun or adjective question: the base word, the requested form in Russian («женский, мн. ч.»),
  four full forms. A form identical to the base word is never asked.
- After an answer: the right option turns green and a wrong pick red, the verdict is also
  written out («Верно» or «Правильный ответ»), the full form is shown with marks and IPA,
  then «Дальше».
- End screen: `right из total` and the number of mistakes.

### 3.8 «Разбор» → «Читалка»
- Text field and «Разобрать».
- Result: the phrase with the pronunciation layer always on, the full IPA line, translation,
  listen button. Words open the same popover as in lesson texts.
- Three counters: silent letters, liaisons, nasal vowels.
- A legend of the three marks, then example phrases.

### 3.9 «Разбор» → «Слово», and the pushed «Разбор слова» screen
The same view in both places.
- Input accepts any form of a word (`buvons`, `petites`, `l'enfant`, `nous buvons`).
- Header: base form with marks, IPA, listen button, translation.
- Facts: part of speech, then by kind: verb group, past participle and auxiliary; gender for a
  noun; position for an adjective. Also silent letters, nasal vowels, lesson, card status.
- Forms:
  - verb: tense switch (`Présent · Imparfait · Futur` in the sample data) and six rows
    (person in Russian, form with marks, IPA);
  - noun: 2×2 grid, definite and indefinite article by singular and plural;
  - adjective: 2×2 grid, masculine and feminine by singular and plural.
  - Each set has a one-line note on what to notice. The form the learner came from is highlighted.
    Tapping a form speaks it.
- «Тренировать формы» starts a drill on this word; «Открыть урок N» goes to the lesson.

### 3.10 «Словарь» (search)
- Every word grouped by lesson; a lesson filter as chips; the search field lives in the tab bar.
- Matches the French word without marks and the Russian translation, case-insensitive.
- Empty result: a message naming the query and how to widen the search.
- A word opens its analysis (3.9).

## 4. Pronunciation system

One visual language everywhere French is shown with marks: lesson texts, card backs, rules,
reader, word analysis, drills.

| Mark | Meaning | Shown as | Sample markup |
|---|---|---|---|
| silent | letters that are not pronounced | paler, lighter weight, dotted underline | `parl(ent)` |
| nasal | nasal vowel | soft ochre underlay | `mat[in]` |
| link | consonant heard only because of a liaison | accent colour, bold | `le{s}` |
| arc | liaison between two words | accent arc under the gap | `le{s}‿ami(s)` |

- Silence is never shown by colour alone: weight and underline carry it too.
- IPA sits under each word when the layer is on, and in brackets elsewhere.
- In a lesson text the liaison is a field on the following word, not a character in the string:
  the token carries the liaison consonant (`z`, `t`, `n`), and phrase IPA is written `il z‿ɔ̃`.
- IPA must be set in a font that holds a base letter and its combining tilde in one file.
  Subsetted web fonts split them and the nasal vowels render broken; the prototype uses
  system fonts for IPA for that reason.

## 5. Content model

Shapes as used by the prototype. Names are suggestions; the relationships are the point.

| Entity | Fields | Notes |
|---|---|---|
| Lesson | number, French title, Russian topic | Everything else hangs off the lesson number |
| Word | lesson, French with marks, IPA, translation | Words added from the reader have no lesson |
| Text | lesson, sentences | One text per lesson in the sample data |
| Sentence | translation, tokens | |
| Token | French with marks, IPA, gloss, liaison consonant, rule id; or punctuation | Last two are optional |
| Rule | id, lesson, kind, title, summary, paragraphs, table, examples | Table columns are typed: French, IPA, plain |
| Paradigm | lemma, kind (verb, noun, adjective), facts, sets | A set is a tense, or the gender and number grid |
| Form | lead (pronoun or article), body, IPA | Split so drills can hide the lead |
| Note | target (lesson text or rule), text, optional quoted fragment with word range | |
| Set | first lesson, last lesson | Progress is derived from card states |
| Card state | word, status (new, learning, due, known), scheduling data | Depends on the algorithm in 6.2 |

## 6. What the prototype fakes

Each item below works in the prototype only on hand-written samples or not at all.

### 6.1 Persistence
Notes, saved sets, card states and added words live in memory and vanish on reload. The app
must store them on the device. Syncing between devices is not designed.

### 6.2 Spaced repetition
The intervals on the grade buttons are fixed labels. The app needs a real scheduler: a pure
function from (card state, grade, current time) to the next state and due date, with tests.
Recommendation: SM-2 with four grades, as in classic Anki; it is small enough to own.
FSRS, which Anki uses now, is the heavier alternative. The daily limit of new cards is not designed.

### 6.3 Transcription of arbitrary text
All IPA and marks in `data.js` are typed by hand. The reader recognises three phrases.
A real engine has to produce, for any French text: IPA per word, the silent, nasal and liaison
marks, and the liaisons between words. This is the hardest part of the project:
- IPA per word can come from a pronunciation dictionary.
- Marks need an alignment of spelling against pronunciation, which no dictionary ships.
- Liaison depends on the pair of words and their grammar.

The hand-annotated lesson texts and reader samples are ready-made test fixtures for it.

### 6.4 Word forms
Eight paradigms are typed by hand (parler, boire, être, petit, cher, famille, enfant, pain).
The app needs forms for any word in the lessons at least: conjugation by tense and person,
gender and number for nouns and adjectives, and the reverse lookup from a form to its lemma.

### 6.5 Audio
The prototype calls the browser's speech synthesis, which depends on an installed French voice.
The app should use the system French voice on the device. Not designed: playback speed,
highlighting words while they are read.

### 6.6 Content
Twelve sample lessons; only lessons 5 and 7 have a text and rules. Translations and glosses
are Russian. Where real lesson content comes from is undecided (section 8).

## 7. Visual design

- Tokens are defined once in `prototype/styles.css` under `:root`, with dark values in the two
  dark blocks. Take colours, radii and type sizes from there instead of copying them here.
- Glass (blur, light edge) is only for the navigation layer: tab bar, navigation buttons,
  popover, sheets, the notes button. Content sits on opaque surfaces.
- Two type roles: the system sans for the interface, a serif for French study text.
- One accent (ultramarine) for interactive elements, selection and liaison. Ochre is reserved
  for nasal vowels. Red, amber and green appear only on grades, verdicts and card status.
- Corner radii are concentric: an inner element's radius is the outer radius minus the gap.
- Both themes are designed. Motion is disabled under the reduced-motion setting.
- Touch targets are at least 44 pt.

## 8. Open decisions

Blocked on the project owner. Asked on 2026-11-12, not answered yet.

1. **Stack.** This machine is NixOS without Xcode.
   - Expo / React Native (recommended): developed here, runs on the iPhone through Expo Go,
     store builds in the cloud. Checked against the official docs on 2026-11-12: `expo-glass-effect`
     exists, is listed as included in Expo Go, needs iOS 26 and falls back to a plain view below it.
     Not checked: the native tab bar API in Expo Router, reported as unstable.
   - SwiftUI: real Liquid Glass, but nothing can be compiled or run here; needs a Mac.
   - PWA: grow the prototype into an installable web app; verifiable here, not a native app.
2. **Content source.** Files prepared from the owner's materials, an editor inside the app, or
   the sample lessons for now.
3. **Engine for 6.3 and 6.4.** A bundled offline dictionary (recommended: no network, no cost,
   limited to the words it has), a language-model API, or lesson content only, with the reader
   and free word lookup left out of the first version.

## 9. Build order

Each step is usable on its own and ends with something to check on a phone.

1. App shell: tabs, per-tab stacks, tokens, both themes, sample content loaded from files.
2. Lesson list and lesson text: pronunciation layer, word and phrase selection, popover, audio.
3. Notes, stored on the device.
4. Cards: lesson-range sets, session, scheduler, stored card states.
5. Rules and the link from a word to its rule.
6. Word analysis and form drills on the eight sample paradigms.
7. Search.
8. Engines for arbitrary text and words, once decision 3 is made.

## 10. Not designed

Onboarding, settings, accounts and sync, notifications and reminders, statistics,
editing or deleting notes, a list of all notes, iPad layout, text sizes beyond the default.
