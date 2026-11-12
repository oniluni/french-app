// Reader for Lexique 3.83 (http://www.lexique.org, CC BY-SA 4.0): about 140 000 French word forms
// with pronunciation, lemma, part of speech, gender, number and verb tags.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const SOURCE_URL = 'https://www.lexique.org/databases/Lexique383/Lexique383.tsv';
export const DEFAULT_PATH = new URL('../.cache/lexique/Lexique383.tsv', import.meta.url).pathname;

/** Lexique's one-character phoneme code → IPA. Codes not listed are already IPA. */
const PHONEMES = {
  R: 'ʁ', E: 'ɛ', O: 'ɔ', '°': 'ə', 2: 'ø', 9: 'œ', '@': 'ɑ̃', '§': 'ɔ̃', 5: 'ɛ̃', 1: 'œ̃',
  g: 'ɡ', S: 'ʃ', Z: 'ʒ', N: 'ɲ', G: 'ŋ', 8: 'ɥ',
};
export const toIpa = (phon) => [...phon].map((code) => PHONEMES[code] ?? code).join('');

/** Lexique spells the ligature as two letters: soeur, oeil. */
const withLigature = (word) => word.replace(/oeu/g, 'œu').replace(/\boeil/g, 'œil');

/** Lookup key: case, ligature and apostrophe style do not matter. */
export const keyOf = (word) => word.normalize('NFC').toLowerCase().replaceAll('œ', 'oe').replaceAll('’', "'").trim();

export async function download(path = DEFAULT_PATH) {
  if (existsSync(path)) return;
  const response = await fetch(SOURCE_URL);
  if (!response.ok) throw new Error(`Lexique download failed: ${response.status} ${SOURCE_URL}`);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, Buffer.from(await response.arrayBuffer()));
}

/**
 * @returns {{ortho: string, ipa: string, lemma: string, pos: string, gender: string, number: string,
 *   tags: string[], frequency: number}[]}
 */
export function loadRows(path = DEFAULT_PATH) {
  const [header, ...lines] = readFileSync(path, 'utf8').split('\n');
  const column = Object.fromEntries(header.split('\t').map((name, index) => [name, index]));
  for (const name of ['ortho', 'phon', 'lemme', 'cgram', 'genre', 'nombre', 'freqfilms2', 'freqlivres', 'infover']) {
    if (!(name in column)) throw new Error(`Lexique file ${path} has no "${name}" column`);
  }
  return lines.filter(Boolean).map((line) => {
    const cell = line.split('\t');
    return {
      ortho: withLigature(cell[column.ortho]),
      ipa: toIpa(cell[column.phon]),
      lemma: withLigature(cell[column.lemme]),
      pos: cell[column.cgram],
      gender: cell[column.genre],
      number: cell[column.nombre],
      tags: cell[column.infover].split(';').filter(Boolean),
      frequency: Number(cell[column.freqfilms2]) + Number(cell[column.freqlivres]),
    };
  });
}

/** Rows grouped by lookup key, the most frequent reading first. */
export function indexByForm(rows) {
  const byKey = new Map();
  for (const row of rows) {
    const key = keyOf(row.ortho);
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push(row);
  }
  for (const group of byKey.values()) group.sort((a, b) => b.frequency - a.frequency);
  return byKey;
}

/** Whether a word said alone ends in this sound. Undefined for a word Lexique does not have. */
export function endsWithFrom(byKey) {
  return (word, phoneme) => {
    const group = byKey.get(keyOf(word));
    return group ? group.some((row) => row.ipa.normalize('NFD').endsWith(phoneme)) : undefined;
  };
}
