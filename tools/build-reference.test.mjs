import assert from 'node:assert/strict';
import { test } from 'node:test';
import { categoryWords, gapsFor, placeOf, translator } from './build-reference.mjs';
import { EXTRA_WORDS, OWN_WORDS, PHRASES, pairs } from './reference-own.mjs';

const row = (ortho, pos, frequency, lemma = ortho, ipa = '') => ({ ortho, ipa, lemma, pos, gender: '', number: '', tags: [], frequency });

test('a word is placed only where it stands once, not first, and not inside an elided form', () => {
  assert.deepEqual(placeOf('à', 'Je vais à Paris.'), { start: 8, end: 9 });
  assert.equal(placeOf('à', 'À demain !'), null, 'first word: its capital gives it away');
  assert.equal(placeOf('à', "Je vais à Paris et à Lyon."), null, 'twice');
  assert.equal(placeOf('à', "Il reste jusqu'à midi."), null, "jusqu'à is a word of its own");
  assert.equal(placeOf('que', "Je crois qu'il vient."), null);
  assert.deepEqual(placeOf('parce que', 'Je reste parce que il pleut.'), { start: 9, end: 18 });
});

test('translations follow the part of speech: lessons first, then WikDict for the form, then the lemma', () => {
  const content = { lessons: [{ words: [
    { fr: 'sa', pos: 'Притяжательное прилагательное', ru: 'его, её' },
    { fr: 'le / la pianiste', pos: 'Существительное', ru: 'пианист' },
    { fr: 'en', pos: 'Наречие', ru: 'оттуда' },
  ] }] };
  const byPos = new Map([
    ['en', new Map([['préposition', 'в, на']])],
    ['son', new Map([['adjectif_possessif', 'его']])],
    ['car', new Map([['nom', 'автобус'], ['conjonction', 'так как']])],
  ]);
  const translate = translator(content, { byPos });
  assert.equal(translate(row('sa', 'ADJ:pos', 1, 'son')), 'его, её');
  assert.equal(translate(row('ses', 'ADJ:pos', 1, 'son')), 'его', 'through the lemma');
  assert.equal(translate(row('en', 'PRE', 1)), 'в, на', 'the lessons teach the adverb, not the preposition');
  assert.equal(translate(row('car', 'CON', 1)), 'так как');
  assert.equal(translate(row('le', 'ART:def', 1)), undefined, '"le / la pianiste" says nothing of the article');
});

test('a kind lists its common, translated words, most frequent first, with level and marks', () => {
  const rows = [
    row('dans', 'PRE', 900, 'dans', 'dɑ̃'), row('chez', 'PRE', 300, 'chez', 'ʃe'), row('chez', 'PRE', 10, 'chez', 'ʃe'),
    row('hors', 'PRE', 2, 'hors', 'ɔʁ'), row('c', 'PRE', 50), row('zzz', 'PRE', 99), row('et', 'CON', 5000, 'et', 'e'),
  ];
  const translate = (r) => ({ dans: 'в', chez: 'у', hors: 'вне', c: 'с', et: 'и' })[r.ortho];
  const [prepositions, conjunctions] = categoryWords(rows, translate, new Map([['dans', 'A1']]));
  assert.deepEqual(prepositions.words, [
    { fr: 'dans', m: 'd[an](s)', ipa: 'dɑ̃', ru: 'в', level: 'A1' },
    { fr: 'chez', m: 'che(z)', ipa: 'ʃe', ru: 'у' },
  ]);
  assert.deepEqual(conjunctions.words.map((word) => word.fr), ['et']);
});

test('gap sentences: the length closest to the ideal first, at most four per word', () => {
  const sentences = [
    { fr: 'Je vais chez mon ami ce soir après le travail.', ru: '1', src: 'T1' },
    { fr: 'Il dort chez lui.', ru: '2', src: 'T2' },
    { fr: 'Pierre va chez sa mère.', ru: '3', src: 'T4' },
    { fr: 'Chez nous, il fait froid.', ru: '4', src: 'T3' },
  ];
  const gaps = gapsFor([{ fr: 'chez' }], sentences);
  assert.deepEqual(gaps.map((gap) => gap.src), ['T1', 'T4', 'T2']);
  assert.deepEqual(gaps[1], { before: 'Pierre va ', answer: 'chez', after: ' sa mère.', ru: '3', src: 'T4' });
});

test('hand-written lines: "fr = ru | use", the use optional, a missing side fails', () => {
  assert.deepEqual(pairs('au = à + le | слитный артикль\nmerci = спасибо'), [
    { fr: 'au', ru: 'à + le', use: 'слитный артикль' },
    { fr: 'merci', ru: 'спасибо' },
  ]);
  assert.throws(() => pairs('merci спасибо'), /no " = "/);
  assert.throws(() => pairs('merci = спасибо | '), /lacks a side/);
});

test('a hand-written word wins over the sources and says what it is for; an added one comes last', () => {
  const rows = [row('de', 'PRE', 900, 'de', 'də'), row('chez', 'PRE', 300, 'chez', 'ʃe'), row('près', 'PRE', 50, 'près', 'pʁɛ')];
  const translate = (r) => ({ de: 'из, от', chez: 'у', près: 'около' })[r.ortho];
  const own = {
    words: { prepositions: [{ fr: 'de', ru: 'из; о', use: 'принадлежность' }] },
    extra: { prepositions: [{ fr: 'à cause de', ru: 'из-за' }] },
  };
  const [prepositions] = categoryWords(rows, translate, new Map(), own);
  assert.deepEqual(prepositions.words, [
    { fr: 'de', ipa: 'də', ru: 'из; о', use: 'принадлежность' },
    { fr: 'chez', m: 'che(z)', ipa: 'ʃe', ru: 'у' },
    { fr: 'près', m: 'prè(s)', ipa: 'pʁɛ', ru: 'около' },
    { fr: 'à cause de', ru: 'из-за' },
  ]);
  assert.throws(() => categoryWords(rows, translate, new Map(), { words: { prepositions: [{ fr: 'via', ru: 'через' }] } }), /does not list.*via/);
  assert.throws(() => categoryWords(rows, translate, new Map(), { extra: { prepositions: [{ fr: 'chez', ru: 'у' }] } }), /already lists.*chez/);
});

test('gap sentences ask single words only: no compound or elided form', () => {
  const sentences = [{ fr: 'Il reste à cause de la pluie.', ru: '1', src: 'T1' }, { fr: "Le livre d'Anne.", ru: '2', src: 'T2' }];
  assert.deepEqual(gapsFor([{ fr: 'à cause de' }, { fr: "d'" }], sentences), []);
});

test('the hand-written lists have no line twice within a kind', () => {
  const kinds = [...Object.entries(OWN_WORDS), ...Object.entries(EXTRA_WORDS), ...PHRASES.map((kind) => [kind.id, kind.entries])];
  for (const [id, entries] of kinds) {
    const words = entries.map(({ fr }) => fr.toLowerCase());
    assert.deepEqual(words.filter((fr, i) => words.indexOf(fr) !== i), [], id);
  }
});
