#!/usr/bin/env node
// Usage examples for the word analysis screen → App/Resources/examples.tsv.
//
//   node tools/build-examples.mjs
//
// One line per lemma, sorted by key in UTF-8 byte order:  key <TAB> JSON array of examples.
// An example is { fr, ru, src }, `src` being "T123" for Tatoeba sentence 123
// (https://tatoeba.org, CC BY 2.0 FR). The lessons have no texts of their own to take phrases from.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { download as downloadLexique, indexByForm, keyOf, loadRows } from './lexique.mjs';

const RESOURCES = new URL('../App/Resources/', import.meta.url).pathname;
const CACHE = new URL('../.cache/tatoeba/', import.meta.url).pathname;
const TATOEBA = 'https://downloads.tatoeba.org/exports/per_language/';
export const FILES = { fra: 'fra/fra_sentences.tsv', rus: 'rus/rus_sentences.tsv', links: 'fra/fra-rus_links.tsv' };

const PER_LEMMA = 3;
const MIN_LENGTH = 15;
const MAX_LENGTH = 90;
const IDEAL_LENGTH = 40;
/** A reading of a form counts only if it is this common relative to the form's top reading. */
const MIN_RELATIVE_FREQUENCY = 0.1;

/** Downloads and unpacks one Tatoeba export into the cache. Returns its text. */
export async function tatoeba(name) {
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

/** Up to PER_LEMMA examples per lemma, closest to the ideal length first. */
export function buildExamples(pairs, byKey) {
  const byLemma = new Map();
  for (const example of pairs) {
    for (const lemma of lemmasOf(example.fr, byKey)) {
      if (!byLemma.has(lemma)) byLemma.set(lemma, []);
      byLemma.get(lemma).push(example);
    }
  }
  const closeness = (example) => Math.abs(example.fr.length - IDEAL_LENGTH);
  const lines = new Map();
  for (const [lemma, examples] of byLemma) {
    // Two wordings of one sentence share a translation; one of them is enough.
    const chosen = [];
    const translations = new Set();
    for (const example of examples.sort((a, b) => closeness(a) - closeness(b))) {
      if (translations.has(example.ru)) continue;
      translations.add(example.ru);
      chosen.push(example);
      if (chosen.length === PER_LEMMA) break;
    }
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
  await downloadLexique();
  const byKey = indexByForm(loadRows());
  const [fra, rus, links] = await Promise.all([tatoeba(FILES.fra), tatoeba(FILES.rus), tatoeba(FILES.links)]);
  const pairs = tatoebaPairs(fra, rus, links);
  const lines = buildExamples(pairs, byKey);
  writeFileSync(`${RESOURCES}examples.tsv`, serialize(lines));

  console.log(`${pairs.length} Tatoeba pairs`);
  console.log(`${lines.size} lemmas with examples`);
  console.log(`examples.tsv ${(statSync(`${RESOURCES}examples.tsv`).size / 1e6).toFixed(1)} MB`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
