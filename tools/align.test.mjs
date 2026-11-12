// The hand-written markup in prototype/data.js is the acceptance test for the aligner.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';
import { align, joinMarked, mark, phonemesOf } from './align.mjs';

const source = readFileSync(new URL('../prototype/data.js', import.meta.url), 'utf8');
const data = vm.runInNewContext(`${source}\n({ WORD_ROWS, TEXTS, RULES, READER_SAMPLES, ANALYSIS })`);

const plainOf = (marked) => marked.replace(/[()[\]{}]/g, '').replaceAll('‿', ' ');

// Where the engine and the hand-written sample use a different, equally defensible notation.
// Each entry is the engine's answer; the sample is left as it is until the owner decides.
const KNOWN_DIFFERENCES = new Map([
  // "qu" is one grapheme for [k], so only the final e is silent. The sample fades "ue".
  ['la musiq(ue)', 'la musiqu(e)'],
  // The vowel stays nasal in "un enfant" [œ̃ n‿ɑ̃fɑ̃]; the sample drops the nasal mark on u.
  ["u{n}‿[en]f[an](t)", "[u]{n}‿[en]f[an](t)"],
  // Both s and t are silent in "est" [ɛ]. The sample fades only the t.
  ['es(t)', 'e(st)'],
  ['il es(t)', 'il e(st)'],
]);
const engineForm = (marked) => KNOWN_DIFFERENCES.get(marked) ?? marked;

function expectMarked(expected, ipa) {
  assert.equal(mark(plainOf(expected), ipa), engineForm(expected), `${plainOf(expected)} [${ipa}]`);
}

test('vocabulary samples', () => {
  for (const row of Object.values(data.WORD_ROWS).flat()) {
    const [marked, ipa] = row.split('|');
    expectMarked(marked, ipa);
  }
});

test('rule examples and tables', () => {
  for (const rule of data.RULES) {
    for (const example of rule.examples) {
      const [marked, ipa] = example.split('|');
      expectMarked(marked, ipa);
    }
  }
});

test('paradigm forms, with their pronoun or article', () => {
  for (const entry of data.ANALYSIS) {
    for (const set of entry.sets) {
      for (const form of set.forms) {
        const [marked, ipa] = form.replace('+', '').split('|');
        expectMarked(marked, ipa);
      }
    }
  }
});

test('sentences: every word gets its own marks, sounds and liaison consonant', () => {
  const sentences = [...Object.values(data.TEXTS).flatMap((text) => text.sentences), ...data.READER_SAMPLES];
  for (const sentence of sentences) {
    const words = sentence.tokens.filter((raw) => raw.includes('|')).map((raw) => {
      const [marked, ipa, , link = ''] = raw.split('|');
      return { marked, ipa: ipa.replaceAll('g', 'ɡ'), link }; // the samples type a plain g for IPA ɡ
    });
    const expected = words.map((word) => ({ ...word, marked: engineForm(word.marked) }));
    const phraseIpa = words.map((word) => (word.link ? `${word.link}‿${word.ipa}` : word.ipa)).join(' ');
    const aligned = align(words.map((word) => plainOf(word.marked)), phraseIpa);
    assert.ok(aligned, `no alignment for ${sentence.ru}`);
    assert.deepEqual(
      aligned.map(({ marked, ipa, link }) => ({ marked, ipa, link })),
      expected,
      sentence.ru,
    );
  }
});

test('the tie may be written before the liaison consonant or after it', () => {
  const before = align(['six', 'heures'], 'siz‿œʁ');
  const after = align(['les', 'images'], 'le‿zimaʒ');
  assert.equal(joinMarked(before), 'si{x}‿(h)eur(es)');
  assert.equal(joinMarked(after), 'le{s}‿imag(es)');
  assert.deepEqual([after[1].link, after[1].ipa], ['z', 'imaʒ']);
});

test('a consonant that is always pronounced is tied but not marked as a liaison', () => {
  const endsWith = (word, phoneme) => ({ sept: 't', denise: 'z' }[word] === phoneme);
  assert.equal(joinMarked(align(['sept', 'heures'], 'sɛt‿œʁ', endsWith)), 'se(p)t‿(h)eur(es)');
  assert.equal(joinMarked(align(['Denise', 'écrit'], 'dəniz‿ekʁi', endsWith)), 'Denis(e)‿écri(t)');
});

test('words run together in the transcription are still split by their letters', () => {
  const aligned = align(['je', 'regarde', 'les', 'images.'], 'ʒəʁɡaʁdə le‿zimaʒ');
  assert.deepEqual(aligned.map((item) => item.ipa), ['ʒə', 'ʁɡaʁdə', 'le', 'imaʒ']);
  assert.equal(aligned[1].marked, 'r(e)garde');
  assert.equal(aligned[3].marked, 'imag(es).');
});

test('an optional schwa keeps its brackets and its letter stays unmarked', () => {
  const [petit] = align(['petit'], 'p(ə)ti');
  assert.deepEqual([petit.marked, petit.ipa], ['peti(t)', 'p(ə)ti']);
});

test('several words in one token: elision and hyphen', () => {
  assert.equal(mark("n'est-ce pas", 'nɛs pa'), "n'e(st)-c(e) pa(s)");
  assert.equal(mark('ont-ils', 'ɔ̃til'), '[on]{t}-il(s)');
});

test('what the letters cannot produce is skipped, not guessed', () => {
  const [, seven, hours] = align(['à', '7', 'heures'], 'a sɛt œʁ');
  assert.deepEqual([seven.marked, seven.ipa], [null, 'sɛt']);
  assert.deepEqual([hours.marked, hours.ipa], ['(h)eur(es)', 'œʁ']);
  assert.equal(mark('chat', 'ʃjɛ̃'), null);
  const [title, name] = align(['M.', 'Duval'], 'məsjø dyval');
  assert.equal(title.marked, null);
  assert.deepEqual([name.marked, name.ipa], ['Duval', 'dyval']);
});

test('length and stress marks are not sounds', () => {
  assert.deepEqual(phonemesOf("[la-'flœːr]").map((item) => item.p), ['l', 'a', 'f', 'l', 'œ', 'ʁ']);
});
