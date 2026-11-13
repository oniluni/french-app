#!/usr/bin/env node
// Lesson vault (Markdown, one folder per lesson) → App/Resources/content.json.
//
//   node tools/import-vault.mjs <vault directory>
//
// A lesson is imported when its «Дашборд.md» has `lesson: N` in the front matter. Folders
// without it (raw OCR) are skipped, and appear in the app once they are brought to that format.
// A lesson is its rules («Правила.md») and its words («Слова.md»); the vault keeps no texts.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { align, joinMarked, phonemesOf } from './align.mjs';
import { download, endsWithFrom, indexByForm, keyOf, loadRows } from './lexique.mjs';
import { parseBlocks, plainText } from './markdown.mjs';
import { attachTriggers } from './rule-triggers.mjs';

const OUTPUT = new URL('../App/Resources/content.json', import.meta.url).pathname;
const MIN_ALIGNED = 0.97;

const frontMatter = /^---\n([\s\S]*?)\n---\n?/;
const body = (text) => text.replace(frontMatter, '');
const lessonNumber = (text) => Number(/^lesson:\s*(\d+)\s*$/m.exec(frontMatter.exec(text)?.[1] ?? '')?.[1] ?? NaN);
const unbracket = (ipa) => ipa.replace(/[[\]]/g, '').trim();
/** Brackets in the French text itself would be read as pronunciation marks. */
const hasMarkCharacters = (text) => /[()[\]{}‿]/.test(text);
export const plainOf = (marked) => marked.replace(/[()[\]{}]/g, '').replaceAll('‿', ' ');

// ---------------------------------------------------------------------------------------------
// Parsing: Markdown → raw lesson parts. No alignment yet.

const VOCABULARY_HEAD = ['Слово', 'Произношение', 'Перевод', 'Грамматика'];

/**
 * «Слова.md» → the new words of the lesson and the remarks under its conjugation tables. The words
 * are the tables under «Словарь урока», one per group; «Повторяющаяся лексика» repeats words of
 * earlier lessons, which have their cards there.
 */
export function parseVocabulary(markdown) {
  const blocks = parseBlocks(body(markdown));
  const start = blocks.findIndex((block) => block.t === 'h' && block.level === 2 && /Словарь урока/.test(block.md));
  if (start === -1) throw new Error('no «Словарь урока» heading');
  const end = blocks.findIndex((block, i) => i > start && block.t === 'h' && block.level <= 2);
  let group = '';
  const words = [];
  for (const block of blocks.slice(start + 1, end === -1 ? undefined : end)) {
    if (block.t === 'h') group = block.md;
    if (block.t !== 'table' || /Повторяющаяся лексика/.test(group)) continue;
    if (VOCABULARY_HEAD.some((name, i) => block.head[i] !== name)) {
      throw new Error(`table under «${group}» has columns ${block.head.join(' | ')}, expected ${VOCABULARY_HEAD.join(' | ')}`);
    }
    for (const [fr, ipa, ru, pos] of block.rows) {
      // The word is written bold; «\*haut» escapes the star that marks an aspirated h.
      const written = fr.trim().replace(/^\*\*([\s\S]*)\*\*$/, '$1').replace(/\\(.)/g, '$1');
      words.push({ fr: written, pos: plainText(pos), ipa: unbracket(ipa), ru: plainText(ru).replace(/^✎\s*/, '') });
    }
  }
  if (words.length === 0) throw new Error('no words under «Словарь урока»');

  const verbNotes = {};
  let lemma = null;
  for (const block of blocks) {
    if (block.t === 'h') lemma = / — /.test(block.md) ? block.md.split(' — ')[0].trim().toLowerCase() : null;
    const note = block.t === 'p' ? /^\*\*Особенности:\*\*\s*([\s\S]+)$/.exec(block.md) : null;
    if (lemma && note) verbNotes[lemma] = note[1];
  }
  return { words, verbNotes };
}

const RULE_KIND = {
  'Произношение': 'Произношение', 'Правила чтения': 'Чтение', 'Речевой поток': 'Чтение', 'Грамматика': 'Грамматика',
  // Lesson 14 has too many remarks for a callout.
  'Комментарии к словам': 'Примечания',
};

function summaryOf(blocks) {
  const first = blocks.find((block) => block.t === 'p' || block.t === 'list');
  const text = plainText(first?.t === 'list' ? first.items[0].md : first?.md ?? '').split('\n')[0];
  if (text.length <= SUMMARY_LENGTH) return text;
  // Whole sentences that fit; a sentence ends before a capital, so "м. р." does not end one.
  let fits = '';
  for (const sentence of text.split(/(?<=[.!?…])\s+(?=[«A-ZА-ЯЁ])/)) {
    const longer = fits ? `${fits} ${sentence}` : sentence;
    if (longer.length > SUMMARY_LENGTH) break;
    fits = longer;
  }
  if (fits) return fits;
  const cut = text.slice(0, SUMMARY_LENGTH);
  return `${cut.slice(0, cut.lastIndexOf(' ')).replace(/[\s,;:—–-]+$/, '')}…`;
}

const SUMMARY_LENGTH = 110;

/**
 * «Правила.md» → rules: one per second- and third-level heading that has text of its own, plus the
 * two closing callouts. Ids are `<lesson>-r<n>`: the vault's earlier layout numbered its rules
 * `<lesson>-<n>`, and a note kept under such an id must not land on another rule.
 */
export function parseRules(markdown, lesson) {
  const rules = [];
  let group = null;
  const open = (kind, title) => rules.push({ kind, title, blocks: [] });
  for (const block of parseBlocks(body(markdown))) {
    if (block.t === 'h' && block.level === 2) {
      group = block.md;
      open(RULE_KIND[group] ?? group, group);
    } else if (block.t === 'h' && block.level === 3 && group) {
      open(RULE_KIND[group] ?? group, block.md.replace(/^\d+\.\s+/, ''));
    } else if (block.t === 'callout' && ['info', 'warning'].includes(block.kind)) {
      rules.push({ kind: 'Примечания', title: block.title, blocks: block.blocks });
    } else if (group && block.t !== 'hr' && !(block.t === 'callout' && block.kind === 'note')) {
      rules.at(-1).blocks.push(block);
    }
  }
  return rules.filter((rule) => rule.blocks.length > 0)
    .map((rule, index) => ({ id: `${lesson}-r${index + 1}`, ...rule, title: soundsTitle(rule) ?? rule.title, summary: summaryOf(rule.blocks) }));
}

/** «Произношение» opens with a table of the lesson's sounds: «Звук [e]», «Звуки [u], [ɲ]» says more than the kind again. */
function soundsTitle(rule) {
  const table = rule.blocks.find((block) => block.t === 'table');
  if (rule.title !== 'Произношение' || table?.head[0] !== 'Звук') return null;
  const sounds = table.rows.map((row) => plainText(row[0]));
  return `${sounds.length === 1 ? 'Звук' : 'Звуки'} ${sounds.join(', ')}`;
}

// ---------------------------------------------------------------------------------------------
// "Почему так читается": which reading rule explains a word.

const sound = (text) => phonemesOf(text).map((item) => item.p).join('');

/**
 * The rule one row of a «Правила чтения» table states, or null: «ch | [ʃ]», «s на конце слова |
 * обычно не читается», «гласный + n или m в одном слоге | носовой гласный…».
 */
function patternFor(spelling, reading) {
  let found;
  if (/^Сцепление/.test(spelling)) return { kind: 'tie' };
  if (/^носовой гласный при связывании/.test(spelling)) return { kind: 'nasal-link' };
  if (/^носовой гласный/.test(reading)) return { kind: 'nasal' };
  const said = /^(?:обычно |всегда )?\[([^\]]+)\]$/.exec(reading);
  if (said && (found = /^(\p{L}{1,3})(?: перед гласн\p{L}*)?$/u.exec(spelling))) {
    return { kind: 'sound', letters: found[1], sound: sound(said[1]) };
  }
  if ((found = /^(\p{L}) (?:на конце|в окончании)/u.exec(spelling))) {
    if (/не читается/.test(reading)) return { kind: 'silent-final', letter: found[1] };
    if (said) return { kind: 'heard-final', letter: found[1] };
  }
  return null;
}

/**
 * Every reading rule a word can be linked to, in lesson order. The app's reader decides which
 * applies to a word (FrenchCore/ReadingRules.swift, `ReadingPattern.applies`).
 */
function readingRulesOf(lessons) {
  const found = [];
  const add = (rule, label, pattern) => found.push({ rule, label, pattern });
  // The item that says a silent final consonant wakes up before a vowel, not the one on vowel linking.
  const explainsLiaison = (item) => /связывание.{0,40}согласный/i.test(JSON.stringify(item));
  for (const lesson of lessons) {
    for (const rule of lesson.rules.filter((item) => item.kind === 'Чтение')) {
      if (/^h немое/.test(rule.title)) add(rule.id, rule.title, { kind: 'h' });
      for (const table of rule.blocks.filter((block) => block.t === 'table')) {
        for (const row of table.rows) {
          const [spelling, reading] = row.slice(0, 2).map(plainText);
          const pattern = patternFor(spelling, reading);
          // «ch — [ʃ]»; a long explanation («Сцепление»: what it is) stays out of the label.
          if (pattern) add(rule.id, reading.length <= 40 ? `${spelling} — ${reading}` : spelling, pattern);
        }
      }
      // Liaison has no row of its own: a paragraph explains it after the silent final letters.
      if (explainsLiaison(rule.blocks) && !found.some((entry) => entry.pattern.kind === 'liaison')) {
        add(rule.id, 'Связывание', { kind: 'liaison' });
      }
    }
  }
  return found;
}

// ---------------------------------------------------------------------------------------------
// Enrichment: marks on the words.

/** Stand-ins for "something" and "somebody" in dictionary entries: written, never transcribed. */
const PLACEHOLDER = /^(qch|qn|qqn|qqch)[,.]?$/;

function markPhrase(fr, ipa, endsWith) {
  const words = fr.split(/\s+/).filter(Boolean);
  const aligned = align(words, ipa, endsWith);
  if (!aligned || aligned.some((item, i) => item.marked === null && !PLACEHOLDER.test(words[i]))) return null;
  return joinMarked(aligned.map((item, i) => ({ ...item, marked: item.marked ?? words[i] })));
}

/**
 * Vocabulary entry → marked form. Several forms with a sound each ("petit, petite") align as one
 * phrase; one sound for several forms ("joli, jolie" [ʒɔli]) means they are said alike.
 */
function markEntry(fr, ipa, endsWith) {
  if (hasMarkCharacters(fr)) return null;
  // Forms first: as one phrase, "seul, seule" [sœl] aligns with the first word silent.
  if (!/[,/]/.test(ipa)) {
    for (const separator of [' / ', ', ']) {
      const forms = fr.split(separator);
      if (forms.length < 2) continue;
      const marked = forms.map((form) => markPhrase(form, ipa, endsWith));
      if (marked.every(Boolean)) return marked.join(separator);
    }
  }
  return markPhrase(fr, ipa, endsWith);
}

// ---------------------------------------------------------------------------------------------

function readLesson(directory) {
  const read = (name) => {
    const path = join(directory, `${name}.md`);
    return existsSync(path) ? readFileSync(path, 'utf8') : '';
  };
  const dashboard = read('Дашборд');
  const id = lessonNumber(dashboard);
  if (Number.isNaN(id)) return null;
  const stage = (name, parse) => {
    try {
      return parse(read(name));
    } catch (error) {
      throw new Error(`${directory}/${name}.md: ${error.message}`, { cause: error });
    }
  };
  const topic = /^#\s+Урок\s+\d+\.\s*(.+)$/m.exec(dashboard)?.[1].trim() ?? '';
  return { id, topic, ...stage('Слова', parseVocabulary), rules: stage('Правила', (text) => parseRules(text, id)) };
}

export function importVault(vault, lexiqueRows, { triggers } = {}) {
  const lessons = readdirSync(vault, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^Урок \d+$/.test(entry.name))
    .map((entry) => readLesson(join(vault, entry.name)))
    .filter(Boolean)
    .sort((a, b) => a.id - b.id);
  if (lessons.length === 0) throw new Error(`No lesson with "lesson: N" front matter found in ${vault}`);

  const byKey = indexByForm(lexiqueRows);
  const fromLexique = endsWithFrom(byKey);
  // The vocabulary knows the names Lexique does not: "Denise" ends in [z] on its own.
  const said = new Map(lessons.flatMap((lesson) => lesson.words).map((word) => [keyOf(word.fr), word.ipa.normalize('NFD')]));
  const endsWith = (word, phoneme) => (said.has(keyOf(word)) ? said.get(keyOf(word)).endsWith(phoneme) : fromLexique(word, phoneme));

  const readingRules = readingRulesOf(lessons);
  attachTriggers(lessons, readingRules, triggers);
  const report = { words: 0, alignedWords: 0, singleWords: 0, alignedSingleWords: 0, failedWords: [], duplicates: 0 };
  const taught = new Map(); // French entry → translations already given by earlier lessons
  const verbNotes = {};

  const content = lessons.map((lesson) => {
    Object.assign(verbNotes, lesson.verbNotes);
    const words = [];
    for (const word of lesson.words) {
      // The same entry with the same translation is a repeat. With a new translation it is a new
      // meaning and gets a card of its own, or joins the card of this lesson.
      const before = taught.get(word.fr) ?? [];
      taught.set(word.fr, [...before, word.ru]);
      if (before.includes(word.ru)) { report.duplicates += 1; continue; }
      const sameLesson = words.find((other) => other.fr === word.fr);
      if (sameLesson) { sameLesson.ru += `; ${word.ru}`; continue; }
      const marked = markEntry(word.fr, word.ipa, endsWith);
      const isSingle = !/[\s,/(]/.test(word.fr);
      report.words += 1;
      report.singleWords += isSingle ? 1 : 0;
      if (marked) {
        report.alignedWords += 1;
        report.alignedSingleWords += isSingle ? 1 : 0;
      } else {
        report.failedWords.push(`${word.fr} [${word.ipa}]`);
      }
      words.push(marked ? { ...word, m: marked } : word);
    }
    return { id: lesson.id, topic: lesson.topic, words, rules: lesson.rules };
  });

  return {
    content: { version: 1, lessons: content, readingRules: readingRules.map(({ rule, label, pattern }) => ({ rule, label, pattern })), verbNotes },
    report,
  };
}

/** Every marked string must spell exactly the text it came from. */
function validate(content) {
  const check = (marked, where) => {
    let depth = 0;
    for (const char of marked) {
      if ('([{'.includes(char)) depth += 1;
      if (')]}'.includes(char)) depth -= 1;
      if (depth < 0 || depth > 1) throw new Error(`Broken pronunciation markup "${marked}" in ${where}`);
    }
    if (depth !== 0) throw new Error(`Unclosed pronunciation markup "${marked}" in ${where}`);
  };
  for (const lesson of content.lessons) {
    for (const word of lesson.words) {
      if (!word.m) continue;
      check(word.m, `lesson ${lesson.id} vocabulary`);
      if (plainOf(word.m) !== word.fr) throw new Error(`Marked "${word.m}" does not spell "${word.fr}" (lesson ${lesson.id})`);
    }
  }
}

async function main() {
  const vault = process.argv[2];
  if (!vault) {
    console.error('Usage: node tools/import-vault.mjs <vault directory>');
    process.exit(2);
  }
  await download();
  const { content, report } = importVault(vault, loadRows());
  validate(content);
  writeFileSync(OUTPUT, `${JSON.stringify(content)}\n`);

  const share = (part, whole) => `${part}/${whole} (${(100 * part / whole).toFixed(1)}%)`;
  for (const lesson of content.lessons) {
    console.log(`Урок ${String(lesson.id).padStart(2)}: ${lesson.words.length} слов, ${lesson.rules.length} правил`);
  }
  console.log(`\nEntries marked: ${share(report.alignedWords, report.words)}, single words ${share(report.alignedSingleWords, report.singleWords)}; repeated entries skipped: ${report.duplicates}`);
  console.log(`Reading rules that words link to: ${content.readingRules.length}`);
  if (report.failedWords.length > 0) console.log(`\nWords left unmarked:\n  ${report.failedWords.join('\n  ')}`);
  console.log(`\nWrote ${OUTPUT}`);

  if (report.alignedSingleWords / report.singleWords < MIN_ALIGNED) {
    console.error(`Fewer than ${MIN_ALIGNED * 100}% of the single words could be marked. Check the transcriptions listed above.`);
    process.exit(1);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
