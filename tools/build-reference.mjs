#!/usr/bin/env node
// The «Справочник» tab: function words of French by kind, with gap-fill sentences
// → App/Resources/reference.json.
//
//   node tools/build-reference.mjs     (after import-vault, build-examples and build-dictionary)
//
// Words come from Lexique by part of speech. A word is kept when it is common and has a
// translation: the lessons' own first, then WikDict for the form, then WikDict for its lemma.
import { readFileSync, statSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { loadDictionary } from './build-dictionary.mjs';
import { FILES, tatoeba, tatoebaPairs } from './build-examples.mjs';
import { readingOf } from './build-lexicon.mjs';
import { download, keyOf, loadRows } from './lexique.mjs';

const RESOURCES = new URL('../App/Resources/', import.meta.url).pathname;

/** Kinds of word, by Lexique part-of-speech code. `gaps`: the kind is drilled with gap-fill sentences. */
export const CATEGORIES = [
  { id: 'prepositions', title: 'Предлоги', pos: ['PRE'], gaps: true },
  { id: 'conjunctions', title: 'Союзы', pos: ['CON'], gaps: true },
  { id: 'articles', title: 'Артикли', pos: ['ART:def', 'ART:ind'] },
  { id: 'personal', title: 'Личные местоимения', pos: ['PRO:per'] },
  { id: 'demonstrative', title: 'Указательные и притяжательные', pos: ['ADJ:dem', 'PRO:dem', 'ADJ:pos', 'PRO:pos'] },
  { id: 'interrogative', title: 'Вопросительные и относительные', pos: ['ADJ:int', 'PRO:int', 'PRO:rel'] },
  { id: 'indefinite', title: 'Неопределённые слова', pos: ['ADJ:ind', 'PRO:ind'] },
  { id: 'numbers', title: 'Числительные', pos: ['ADJ:num'] },
];

/** Occurrences per million (films and books together) below which a form is not listed. */
const MIN_FREQUENCY = 5;
const MAX_WORDS = 40;
/** Lexique artefacts: letters and fragments tagged as function words. */
const NOT_WORDS = new Set(['c', 't', 'x', 'con', 'force', 'plein']);
const GAPS_PER_WORD = 4;
const IDEAL_LENGTH = 45;

/** Lexique part of speech → how the lessons describe it, and WikDict's names for it. */
const KINDS = {
  PRE: { lesson: /предлог/i, wikdict: ['préposition'] },
  CON: { lesson: /союз/i, wikdict: ['conjonction', 'conjonction_de_coordination'] },
  'ART:def': { lesson: /артикл/i, wikdict: ['article_défini'] },
  'ART:ind': { lesson: /артикл/i, wikdict: ['article_indéfini'] },
  'PRO:per': { lesson: /личн/i, wikdict: ['pronom_personnel', 'pronom'] },
  'PRO:dem': { lesson: /указательн/i, wikdict: ['pronom_démonstratif'] },
  'ADJ:dem': { lesson: /указательн/i, wikdict: ['adjectif_démonstratif'] },
  'PRO:pos': { lesson: /притяжательн/i, wikdict: ['pronom_possessif'] },
  'ADJ:pos': { lesson: /притяжательн/i, wikdict: ['adjectif_possessif'] },
  'PRO:ind': { lesson: /неопредел/i, wikdict: ['pronom_indéfini'] },
  'ADJ:ind': { lesson: /неопредел/i, wikdict: ['adjectif_indéfini'] },
  'PRO:int': { lesson: /вопросительн/i, wikdict: ['pronom_interrogatif'] },
  'ADJ:int': { lesson: /вопросительн/i, wikdict: ['adjectif_interrogatif'] },
  'PRO:rel': { lesson: /относительн/i, wikdict: ['pronom_relatif'] },
  'ADJ:num': { lesson: /числительн/i, wikdict: ['adjectif_numéral'] },
};

/**
 * Translation of a form as the part of speech it is listed under: the lessons' own when they
 * describe it so, then WikDict's entry for that part of speech, for the form and then its lemma.
 * There is no fallback to other parts of speech: "car" the conjunction is not «автобус».
 */
export function translator(content, { byPos }) {
  const lessons = new Map();
  for (const word of content.lessons.flatMap((lesson) => lesson.words)) {
    const parts = word.fr.split(/, | \/ /);
    // "petit, petite" lists two forms; "le / la pianiste" is one entry, not the word "le".
    const forms = parts.every((part) => !part.includes(' ')) ? parts : [word.fr];
    for (const form of forms) {
      const key = keyOf(form);
      if (!lessons.has(key)) lessons.set(key, []);
      lessons.get(key).push(word);
    }
  }
  return (row) => {
    const kind = KINDS[row.pos];
    const taught = lessons.get(keyOf(row.ortho))?.find((word) => kind.lesson.test(word.pos ?? ''));
    if (taught) return taught.ru;
    for (const key of [keyOf(row.ortho), keyOf(row.lemma)]) {
      const senses = kind.wikdict.map((pos) => byPos.get(key)?.get(pos)).find(Boolean);
      if (senses) return senses;
    }
    return undefined;
  };
}

/** The common words of each kind, most frequent first. */
export function categoryWords(rows, translate, levels) {
  return CATEGORIES.map((category) => {
    const best = new Map();
    for (const row of rows) {
      if (!category.pos.includes(row.pos) || row.frequency < MIN_FREQUENCY || NOT_WORDS.has(row.ortho)) continue;
      const previous = best.get(row.ortho);
      if (!previous || row.frequency > previous.frequency) best.set(row.ortho, row);
    }
    const words = [...best.values()]
      .sort((a, b) => b.frequency - a.frequency)
      .map((row) => ({ row, ru: translate(row) }))
      .filter(({ ru }) => ru)
      .slice(0, MAX_WORDS)
      .map(({ row, ru }) => {
        const { marked, ipa } = readingOf(row.ortho, row.ipa);
        const level = levels.get(keyOf(row.ortho)) ?? levels.get(keyOf(row.lemma));
        return { fr: row.ortho, ...(marked !== row.ortho ? { m: marked } : {}), ipa, ru, ...(level ? { level } : {}) };
      });
    return { ...category, words };
  });
}

const WORD = /\p{L}+(?:[-'’]\p{L}+)*/gu;

/**
 * Where a word stands in a sentence, if it stands there exactly once and not first: the first
 * word would give itself away by its capital. "jusqu'à" and "qu'il" are words of their own, so
 * they never count as "à" or "que".
 */
export function placeOf(word, sentence) {
  const parts = word.toLowerCase().split(' ');
  const tokens = [...sentence.matchAll(WORD)];
  const found = [];
  for (let i = 0; i + parts.length <= tokens.length; i++) {
    if (parts.every((part, k) => tokens[i + k][0].toLowerCase() === part)) found.push(i);
  }
  if (found.length !== 1 || found[0] === 0) return null;
  const first = tokens[found[0]];
  const last = tokens[found[0] + parts.length - 1];
  return { start: first.index, end: last.index + last[0].length };
}

/** Gap-fill sentences of a kind from Tatoeba, readable length first. */
export function gapsFor(words, sentences) {
  const gaps = [];
  for (const word of words) {
    const found = [];
    for (const sentence of sentences) {
      const place = placeOf(word.fr, sentence.fr);
      if (place) found.push({ sentence, place });
    }
    const rank = ({ sentence }) => Math.abs(sentence.fr.length - IDEAL_LENGTH);
    for (const { sentence, place } of found.sort((a, b) => rank(a) - rank(b)).slice(0, GAPS_PER_WORD)) {
      gaps.push({
        before: sentence.fr.slice(0, place.start),
        answer: sentence.fr.slice(place.start, place.end),
        after: sentence.fr.slice(place.end),
        ru: sentence.ru,
        src: sentence.src,
      });
    }
  }
  return gaps;
}

async function main() {
  const content = JSON.parse(readFileSync(`${RESOURCES}content.json`, 'utf8'));
  await download();
  const rows = loadRows();
  const { translations, levels } = await loadDictionary();
  const [fra, rus, links] = await Promise.all([tatoeba(FILES.fra), tatoeba(FILES.rus), tatoeba(FILES.links)]);
  const sentences = tatoebaPairs(fra, rus, links);

  const categories = categoryWords(rows, translator(content, translations), levels).map(({ pos, gaps, ...category }) => ({
    ...category,
    ...(gaps ? { gaps: gapsFor(category.words, sentences) } : {}),
  }));
  writeFileSync(`${RESOURCES}reference.json`, `${JSON.stringify({ categories })}\n`);
  for (const category of categories) {
    console.log(`${category.title}: ${category.words.length} words${category.gaps ? `, ${category.gaps.length} gap sentences` : ''}`);
  }
  console.log(`reference.json ${(statSync(`${RESOURCES}reference.json`).size / 1e3).toFixed(0)} kB`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
