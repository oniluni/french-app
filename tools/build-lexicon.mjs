#!/usr/bin/env node
// Lexique 3.83 → the two lookup files bundled with the app.
//
//   node tools/build-lexicon.mjs        (run after import-vault.mjs: it reads content.json)
//
// App/Resources/lexicon.tsv, one line per spelling, sorted by key (UTF-8 byte order):
//   key <TAB> readings <TAB> analyses
//   readings  marked=ipa|marked=ipa         most frequent first
//   analyses  lemma;pos;gender;number;tag,tag;reading|…
// App/Resources/lemmas.tsv, one line per lemma and word class (V, N, A), sorted the same way:
//   lemmaKey <TAB> class <TAB> lemma <TAB> form;gender;number;tag,tag|…
//
// Both files are a derivative of Lexique (CC BY-SA 4.0) and are shared under the same licence.
import { existsSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { align, mark } from './align.mjs';
import { download, endsWithFrom, indexByForm, keyOf, loadRows } from './lexique.mjs';

const RESOURCES = new URL('../App/Resources/', import.meta.url).pathname;
const CLASS = { VER: 'V', AUX: 'V', NOM: 'N', ADJ: 'A' };

/**
 * Lexique writes the schwa of "ce" and "premier" as [ø]. Where the letters read the same way
 * with a schwa, it is one.
 * shortcut: a word with both a real [ø] and a schwa keeps [ø] for both, fix when one is reported.
 */
export function readingOf(ortho, ipa, endsWith) {
  const marked = mark(ortho, ipa, endsWith);
  if (ipa.includes('ø')) {
    const withSchwa = ipa.replaceAll('ø', 'ə');
    if (marked && mark(ortho, withSchwa, endsWith) === marked) return { marked, ipa: withSchwa };
  }
  return { marked: marked ?? ortho, ipa };
}

/** Single words of the lesson vocabulary with the sound the textbook gives them. */
export function lessonReadings(content, endsWith) {
  const found = new Map();
  for (const word of content.lessons.flatMap((lesson) => lesson.words)) {
    if (!word.m) continue;
    const tokens = word.fr.split(/\s+/);
    const aligned = align(tokens, word.ipa, endsWith);
    if (!aligned) continue;
    aligned.forEach((item, i) => {
      const text = tokens[i].replace(/[,!?.]+$/, '');
      if (!item.marked || item.marked.includes('{') || item.link || !/^[\p{L}-]+$/u.test(text)) return; // not as said in a liaison
      const key = keyOf(text);
      if (!found.has(key) || tokens.length === 1) found.set(key, { marked: item.marked.replace(/[,!?.]+$/, ''), ipa: item.ipa });
    });
  }
  return found;
}

export function buildLexicon(rows, lessonWords = new Map()) {
  const byKey = indexByForm(rows);
  const endsWith = endsWithFrom(byKey);
  const lexicon = new Map();

  for (const [key, group] of byKey) {
    const weight = new Map();
    for (const row of group) weight.set(row.ipa, (weight.get(row.ipa) ?? 0) + row.frequency);
    const sounds = [...weight.keys()].sort((a, b) => weight.get(b) - weight.get(a));
    const readings = sounds.map((ipa) => readingOf(group.find((row) => row.ipa === ipa).ortho, ipa, endsWith));
    const analyses = [];
    for (const row of group) {
      const pos = row.pos === 'AUX' ? 'VER' : row.pos;
      const entry = [row.lemma, pos, row.gender, row.number, row.tags.join(','), sounds.indexOf(row.ipa)].join(';');
      if (!analyses.includes(entry)) analyses.push(entry);
    }
    lexicon.set(key, { readings, analyses });
  }

  // The textbook's own transcription wins for the words it teaches, and adds the names.
  for (const [key, word] of lessonWords) {
    const reading = { marked: word.marked, ipa: word.ipa };
    const entry = lexicon.get(key);
    if (!entry) {
      lexicon.set(key, { readings: [reading], analyses: [] });
    } else if (!entry.readings.some((known) => known.ipa === word.ipa)) {
      entry.readings[0] = reading;
    }
  }

  const lemmas = new Map();
  for (const row of rows) {
    const wordClass = CLASS[row.pos];
    if (!wordClass) continue;
    const id = `${keyOf(row.lemma)}\t${wordClass}`;
    if (!lemmas.has(id)) lemmas.set(id, { lemma: row.lemma, forms: [] });
    const form = [row.ortho, row.gender, row.number, row.tags.join(',')].join(';');
    if (!lemmas.get(id).forms.includes(form)) lemmas.get(id).forms.push(form);
  }
  return { lexicon, lemmas };
}

/** The app finds a line by binary search over raw bytes, so the order must be byte order. */
const byBytes = ([a], [b]) => Buffer.compare(Buffer.from(a), Buffer.from(b));

export function serialize({ lexicon, lemmas }) {
  const lexiconLines = [...lexicon].sort(byBytes).map(([key, entry]) =>
    [key, entry.readings.map((reading) => `${reading.marked}=${reading.ipa}`).join('|'), entry.analyses.join('|')].join('\t'));
  const lemmaLines = [...lemmas].sort(byBytes).map(([id, entry]) => [id, entry.lemma, entry.forms.join('|')].join('\t'));
  return { lexicon: `${lexiconLines.join('\n')}\n`, lemmas: `${lemmaLines.join('\n')}\n` };
}

async function main() {
  await download();
  const rows = loadRows();
  const contentPath = `${RESOURCES}content.json`;
  if (!existsSync(contentPath)) throw new Error(`${contentPath} is missing. Run tools/import-vault.mjs first.`);
  const lessonWords = lessonReadings(JSON.parse(readFileSync(contentPath, 'utf8')), endsWithFrom(indexByForm(rows)));
  const built = buildLexicon(rows, lessonWords);
  const files = serialize(built);
  writeFileSync(`${RESOURCES}lexicon.tsv`, files.lexicon);
  writeFileSync(`${RESOURCES}lemmas.tsv`, files.lemmas);

  const readings = [...built.lexicon.values()].flatMap((entry) => entry.readings);
  const marked = readings.filter((reading) => /[([{]/.test(reading.marked)).length;
  const megabytes = (name) => (statSync(`${RESOURCES}${name}`).size / 1e6).toFixed(1);
  console.log(`${built.lexicon.size} spellings, ${readings.length} readings (${marked} with marks), ${built.lemmas.size} paradigms`);
  console.log(`${lessonWords.size} lesson words applied`);
  console.log(`lexicon.tsv ${megabytes('lexicon.tsv')} MB, lemmas.tsv ${megabytes('lemmas.tsv')} MB`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
