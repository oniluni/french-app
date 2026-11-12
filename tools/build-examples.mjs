#!/usr/bin/env node
// Usage examples for the word analysis screen → App/Resources/examples.tsv.
//
//   node tools/build-examples.mjs        (run after import-vault.mjs: it reads content.json)
//
// One line per lemma, sorted by key in UTF-8 byte order:  key <TAB> JSON array of examples.
// An example is { fr, ru, src } plus `m` (French with pronunciation marks) for lesson phrases.
// `src` is "L5" for lesson 5 or "T123" for Tatoeba sentence 123.
//
// Lesson phrases come first. Tatoeba (https://tatoeba.org, CC BY 2.0 FR) fills in, so that
// words outside the lessons have examples too.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { download as downloadLexique, indexByForm, keyOf, loadRows } from './lexique.mjs';

const RESOURCES = new URL('../App/Resources/', import.meta.url).pathname;
const CACHE = new URL('../.cache/tatoeba/', import.meta.url).pathname;
const TATOEBA = 'https://downloads.tatoeba.org/exports/per_language/';
const FILES = { fra: 'fra/fra_sentences.tsv', rus: 'rus/rus_sentences.tsv', links: 'fra/fra-rus_links.tsv' };

const PER_SOURCE = 3;
const MIN_LENGTH = 15;
const MAX_LENGTH = 90;
const IDEAL_LENGTH = 40;
/** A reading of a form counts only if it is this common relative to the form's top reading. */
const MIN_RELATIVE_FREQUENCY = 0.1;

/** Downloads and unpacks one Tatoeba export into the cache. Returns its text. */
async function tatoeba(name) {
  const path = `${CACHE}${name.split('/')[1]}`;
  if (!existsSync(path)) {
    mkdirSync(CACHE, { recursive: true });
    const response = await fetch(`${TATOEBA}${name}.bz2`);
    if (!response.ok) throw new Error(`Tatoeba download failed: ${response.status} ${TATOEBA}${name}.bz2`);
    writeFileSync(`${path}.bz2`, Buffer.from(await response.arrayBuffer()));
    const unpacked = spawnSync('bunzip2', ['-f', `${path}.bz2`], { stdio: 'inherit' });
    if (unpacked.status !== 0) throw new Error(`bunzip2 failed on ${path}.bz2 (is bzip2 installed?)`);
  }
  return readFileSync(path, 'utf8');
}

const columns = (text) => text.split('\n').filter(Boolean).map((line) => line.split('\t'));

/** Words of a French sentence, with "l'ami" → "ami" and "qu'il" → "il". */
export function wordsOf(sentence) {
  return (sentence.toLowerCase().match(/[\p{L}’'-]+/gu) ?? [])
    .flatMap((word) => word.split(/['’]/).at(-1).split('-'))
    .filter((word) => word.length > 0);
}

/**
 * Lemma keys a sentence contains, through the dictionary. Rare readings are ignored: "bus" is
 * also a passé simple of "boire", but a sentence about a bus is no example for "boire".
 * shortcut: no tagging by context, so "lit" counts for both "lit" and "lire"; tag sentences if
 * wrong examples show up.
 */
export function lemmasOf(sentence, byKey) {
  const lemmas = new Set();
  for (const word of wordsOf(sentence)) {
    const rows = byKey.get(keyOf(word)) ?? [];
    const top = rows[0]?.frequency ?? 0;
    for (const row of rows) {
      if (row.frequency >= top * MIN_RELATIVE_FREQUENCY) lemmas.add(keyOf(row.lemma));
    }
  }
  return lemmas;
}

/** French–Russian pairs from Tatoeba, of a length that reads well as an example. */
export function tatoebaPairs(fraTsv, rusTsv, linksTsv) {
  const russian = new Map(columns(rusTsv).map(([id, , text]) => [id, text]));
  const french = new Map(columns(fraTsv).map(([id, , text]) => [id, text]));
  const pairs = new Map();
  for (const [fraId, rusId] of columns(linksTsv)) {
    const fr = french.get(fraId);
    const ru = russian.get(rusId);
    if (!fr || !ru || pairs.has(fraId) || fr.length < MIN_LENGTH || fr.length > MAX_LENGTH) continue;
    pairs.set(fraId, { fr, ru, src: `T${fraId}` });
  }
  return [...pairs.values()];
}

/** Lesson phrases as examples; marks are kept when every word of the phrase has them. */
export function lessonExamples(content) {
  const found = [];
  for (const lesson of content.lessons) {
    for (const section of lesson.sections) {
      for (const { sentence } of section.items) {
        if (!sentence?.ru) continue;
        const plain = sentence.tokens.map((token) => (token.m ? token.m.replace(/[()[\]{}]/g, '') : token.t)).join(' ');
        const marked = sentence.tokens.every((token) => token.m)
          ? sentence.tokens.map((token, i) => (i === 0 ? '' : token.tie ? '‿' : ' ') + token.m).join('')
          : undefined;
        found.push({ fr: plain, ...(marked ? { m: marked } : {}), ru: sentence.ru, src: `L${lesson.id}` });
      }
    }
  }
  return found;
}

/** Up to PER_SOURCE examples per lemma from each source, lessons first, shortest-to-ideal first. */
export function buildExamples(lessonPhrases, pairs, byKey) {
  const byLemma = new Map();
  const collect = (examples, isLesson) => {
    for (const example of examples) {
      for (const lemma of lemmasOf(example.fr, byKey)) {
        if (!byLemma.has(lemma)) byLemma.set(lemma, { lesson: [], tatoeba: [] });
        byLemma.get(lemma)[isLesson ? 'lesson' : 'tatoeba'].push(example);
      }
    }
  };
  collect(lessonPhrases, true);
  collect(pairs, false);
  const closeness = (example) => Math.abs(example.fr.length - IDEAL_LENGTH);
  const lines = new Map();
  for (const [lemma, { lesson, tatoeba }] of byLemma) {
    // Two wordings of one sentence share a translation; one of them is enough.
    const best = (examples) => {
      const chosen = [];
      const translations = new Set();
      for (const example of examples.sort((a, b) => closeness(a) - closeness(b))) {
        if (translations.has(example.ru)) continue;
        translations.add(example.ru);
        chosen.push(example);
        if (chosen.length === PER_SOURCE) break;
      }
      return chosen;
    };
    const chosen = [...best(lesson), ...best(tatoeba)];
    lines.set(lemma, chosen);
  }
  return lines;
}

/** The app finds a line by binary search over raw bytes, so the order must be byte order. */
export function serialize(lines) {
  const sorted = [...lines].sort(([a], [b]) => Buffer.compare(Buffer.from(a), Buffer.from(b)));
  return `${sorted.map(([lemma, examples]) => `${lemma}\t${JSON.stringify(examples)}`).join('\n')}\n`;
}

async function main() {
  const contentPath = `${RESOURCES}content.json`;
  if (!existsSync(contentPath)) throw new Error(`${contentPath} is missing. Run tools/import-vault.mjs first.`);
  await downloadLexique();
  const byKey = indexByForm(loadRows());
  const [fra, rus, links] = await Promise.all([tatoeba(FILES.fra), tatoeba(FILES.rus), tatoeba(FILES.links)]);
  const pairs = tatoebaPairs(fra, rus, links);
  const lessonPhrases = lessonExamples(JSON.parse(readFileSync(contentPath, 'utf8')));
  const lines = buildExamples(lessonPhrases, pairs, byKey);
  writeFileSync(`${RESOURCES}examples.tsv`, serialize(lines));

  const withLesson = [...lines.values()].filter((examples) => examples.some((example) => example.src.startsWith('L'))).length;
  console.log(`${pairs.length} Tatoeba pairs, ${lessonPhrases.length} lesson phrases`);
  console.log(`${lines.size} lemmas with examples, ${withLesson} of them from the lessons`);
  console.log(`examples.tsv ${(statSync(`${RESOURCES}examples.tsv`).size / 1e6).toFixed(1)} MB`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
