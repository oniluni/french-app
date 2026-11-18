#!/usr/bin/env node
// The hand-written themes (tools/themes.mjs) → App/Resources/themes.json.
//
//   node tools/build-themes.mjs
//
// Pronunciation comes from lexicon.tsv, the file the reader already uses. A word missing from
// Lexique (a compound, a reflexive verb) may carry its own `ipa` in the source.
import { readFileSync, statSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { keyOf } from './lexique.mjs';
import { THEMES } from './themes.mjs';

const RESOURCES = new URL('../App/Resources/', import.meta.url).pathname;
const ARTICLES = ['le ', 'la ', 'les ', 'un ', 'une ', "l'", 'l’'];

export function bare(fr) {
  const lower = fr.trim().toLowerCase();
  const article = ARTICLES.find((article) => lower.startsWith(article));
  return article ? lower.slice(article.length) : lower;
}

const hasArticle = (fr) => bare(fr) !== fr.trim().toLowerCase();

/**
 * The first reading of every spelling in lexicon.tsv:
 *   key <TAB> marked=ipa|marked=ipa <TAB> analyses
 * The marked form is the spelling with silent letters in braces; not every word has one.
 */
export function readLexicon(text) {
  const readings = new Map();
  for (const line of text.split('\n')) {
    if (!line) continue;
    const [key, readingsCell] = line.split('\t');
    const first = (readingsCell ?? '').split('|')[0];
    if (first && !readings.has(key)) readings.set(key, first);
  }
  return readings;
}

function parseReading(text) {
  const at = text.indexOf('=');
  if (at < 0) return { marked: text, ipa: '' };
  return { marked: text.slice(0, at), ipa: text.slice(at + 1) };
}

/** A source word with its pronunciation and the fields of FrenchCore.Word. */
export function themeWord(word, readings) {
  const key = keyOf(word.key ?? bare(word.fr));
  const known = readings.get(key);
  const reading = known ? parseReading(known) : undefined;
  const result = {
    fr: word.fr,
    ipa: word.ipa ?? reading?.ipa ?? '',
    ru: word.ru,
    pos: '',
  };
  // A marked spelling of the bare word only: "la famille" is not "famill(e)".
  if (!word.ipa && reading?.marked && reading.marked !== word.fr && !hasArticle(word.fr)) result.m = reading.marked;
  return result;
}

export function buildThemes(themes, readings) {
  return themes.map((theme) => ({
    id: theme.id,
    title: theme.title,
    icon: theme.icon,
    words: theme.words.map((word) => themeWord(word, readings)),
  }));
}

export function serialize(themes, readings) {
  const seen = new Set();
  for (const theme of themes) {
    if (!theme.id || !theme.title || !theme.icon) throw new Error(`theme ${theme.id || '(no id)'}: id, title and icon are required`);
    if (seen.has(theme.id)) throw new Error(`theme ${theme.id} is listed twice`);
    seen.add(theme.id);
    const words = new Set();
    for (const word of theme.words) {
      if (!word.fr?.trim() || !word.ru?.trim()) throw new Error(`theme ${theme.id}: a word needs a French form and a translation`);
      const key = keyOf(word.key ?? bare(word.fr));
      if (words.has(key)) throw new Error(`theme ${theme.id}: ${word.fr} is listed twice`);
      words.add(key);
    }
  }
  return `${JSON.stringify({ version: 1, themes: buildThemes(themes, readings) }, null, 2)}\n`;
}

function main() {
  const path = `${RESOURCES}themes.json`;
  const readings = readLexicon(readFileSync(`${RESOURCES}lexicon.tsv`, 'utf8'));
  const output = serialize(THEMES, readings);
  writeFileSync(path, output);
  console.log(`${THEMES.length} themes, ${THEMES.flatMap((theme) => theme.words).length} words`);
  console.log(`themes.json ${(statSync(path).size / 1e3).toFixed(1)} kB`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
