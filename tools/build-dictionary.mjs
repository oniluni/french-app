#!/usr/bin/env node
// Translations and CEFR levels of French lemmas → App/Resources/dictionary.tsv.
//
//   node tools/build-dictionary.mjs
//
// One line per lemma, sorted by key in UTF-8 byte order:  key <TAB> level <TAB> translation
// Either field may be empty.
//
// - Translations: WikDict French–Russian (https://www.wikdict.com, from Wiktionary, CC BY-SA).
//   The lessons' own translations are used before these wherever the app has both.
// - Levels: FLELex CRF (https://cental.uclouvain.be/cefrlex/flelex/, CC BY-NC-SA 4.0): the first
//   CEFR level at which the word occurs in FLE textbooks.
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { pathToFileURL } from 'node:url';
import { keyOf } from './lexique.mjs';

const RESOURCES = new URL('../App/Resources/', import.meta.url).pathname;
const CACHE = new URL('../.cache/dictionary/', import.meta.url).pathname;
const SOURCES = {
  wikdict: 'https://download.wikdict.com/dictionaries/sqlite/2/fr-ru.sqlite3',
  flelex: 'https://cental.uclouvain.be/cefrlex/static/resources/fr/FleLex_CRF.csv',
};
export const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const SENSES = 3;

export async function download(name) {
  const path = `${CACHE}${SOURCES[name].split('/').at(-1)}`;
  if (existsSync(path)) return path;
  mkdirSync(CACHE, { recursive: true });
  const response = await fetch(SOURCES[name]);
  if (!response.ok) throw new Error(`${name} download failed: ${response.status} ${SOURCES[name]}`);
  writeFileSync(path, Buffer.from(await response.arrayBuffer()));
  return path;
}

/** FLELex CSV (tab-separated) → lemma key → the first level the word occurs at, over all its tags. */
export function levelsFrom(csv) {
  const [header, ...lines] = csv.split('\n').filter(Boolean);
  const columns = header.split('\t');
  const at = LEVELS.map((level) => columns.indexOf(`freq_${level.toLowerCase()}`));
  if (at.some((index) => index < 0)) throw new Error(`FLELex header lacks a level column: ${header}`);
  const levels = new Map();
  for (const line of lines) {
    const cells = line.split('\t');
    const first = at.findIndex((index) => Number(cells[index]) > 0);
    if (first < 0) continue;
    const key = keyOf(cells[0]);
    if (!levels.has(key) || first < LEVELS.indexOf(levels.get(key))) levels.set(key, LEVELS[first]);
  }
  return levels;
}

/** WikDict's part of speech in an entry id: "fra/que__conjonction__1" → "conjonction". */
export const partOfSpeech = (lexentry) => /__(.+)__\d+$/.exec(lexentry ?? '')?.[1] ?? null;

/** Names are no translation of a word: "sinon" is not «Синон». */
const NAMES = new Set(['nompr', 'prénom', 'nom_de_famille', 'patronyme']);

/** Wiktionary leftovers: stress marks and [[link|text]] markup. */
export const cleanSense = (sense) => sense
  .normalize('NFD').replace(/́/g, '').normalize('NFC')
  .replace(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/g, '$1')
  .trim();

/**
 * WikDict rows → for each lemma key, its first senses over all parts of speech (`any`), and per
 * part of speech (`byPos`), best-scored entries first.
 */
export function translationsFrom(rows) {
  const collect = new Map();
  for (const row of [...rows].sort((a, b) => b.score - a.score)) {
    const pos = partOfSpeech(row.lexentry);
    if (!pos || NAMES.has(pos)) continue;
    const key = keyOf(row.written_rep);
    if (!collect.has(key)) collect.set(key, { any: [], byPos: new Map() });
    const entry = collect.get(key);
    if (!entry.byPos.has(pos)) entry.byPos.set(pos, []);
    for (const sense of row.trans_list.split(' | ').map(cleanSense).filter(Boolean)) {
      if (!entry.any.includes(sense)) entry.any.push(sense);
      if (!entry.byPos.get(pos).includes(sense)) entry.byPos.get(pos).push(sense);
    }
  }
  const join = (senses) => senses.slice(0, SENSES).join(', ');
  return {
    any: new Map([...collect].map(([key, entry]) => [key, join(entry.any)])),
    byPos: new Map([...collect].map(([key, entry]) => [key, new Map([...entry.byPos].map(([pos, senses]) => [pos, join(senses)]))])),
  };
}

/** The app finds a line by binary search over raw bytes, so the order must be byte order. */
export function serialize(levels, translations) {
  const keys = [...new Set([...levels.keys(), ...translations.keys()])]
    .filter((key) => key && !/[\t\n]/.test(key))
    .sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)));
  return `${keys.map((key) => [key, levels.get(key) ?? '', translations.get(key) ?? ''].join('\t')).join('\n')}\n`;
}

export async function loadDictionary() {
  const db = new DatabaseSync(await download('wikdict'), { readOnly: true });
  try {
    const translations = translationsFrom(db.prepare('SELECT written_rep, lexentry, trans_list, score FROM translation').all());
    const levels = levelsFrom(readFileSync(await download('flelex'), 'utf8'));
    return { translations, levels };
  } finally {
    db.close();
  }
}

async function main() {
  const { translations, levels } = await loadDictionary();
  writeFileSync(`${RESOURCES}dictionary.tsv`, serialize(levels, translations.any));
  console.log(`${translations.any.size} translated lemmas, ${levels.size} with a CEFR level`);
  console.log(`dictionary.tsv ${(statSync(`${RESOURCES}dictionary.tsv`).size / 1e6).toFixed(1)} MB`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
