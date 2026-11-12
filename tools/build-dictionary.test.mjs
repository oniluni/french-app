import assert from 'node:assert/strict';
import { test } from 'node:test';
import { levelsFrom, serialize, translationsFrom } from './build-dictionary.mjs';

test('a level is the first one the word occurs at, over all its tags', () => {
  const csv = [
    'word\ttag\tfreq_a1\tfreq_a2\tfreq_b1\tfreq_b2\tfreq_c1\tfreq_c2\tfreq_total\t',
    'néanmoins\tADV\t0.0\t0.0\t29.8\t1.5\t51.6\t105.8\t17.6\t',
    'parler\tN\t0.0\t0.0\t0.0\t0.0\t3.1\t142.6\t7.7\t',
    'parler\tV\t1265.5\t1496.4\t1017.4\t1189.5\t637.2\t147.4\t1114.8\t',
    'jamais-vu\tN\t0.0\t0.0\t0.0\t0.0\t0.0\t0.0\t0.0\t',
  ].join('\n');
  const levels = levelsFrom(csv);
  assert.deepEqual([...levels], [['néanmoins', 'B1'], ['parler', 'A1']]);
});

test('a header without the level columns is rejected', () => {
  assert.throws(() => levelsFrom('word\ttag\tfreq_total\n'), /level column/);
});

test('translations: best scored first, three senses, per part of speech, no names or markup', () => {
  const { any, byPos } = translationsFrom([
    { written_rep: 'Voiture', lexentry: 'fra/voiture__nom__1', trans_list: 'машина | автомобиль', score: 127.7 },
    { written_rep: 'voiture', lexentry: 'fra/voiture__nom__2', trans_list: 'вагон | карета | повозка', score: 50 },
    { written_rep: 'sinon', lexentry: 'fra/sinon__nompr__1', trans_list: 'Синон', score: 200 },
    { written_rep: 'sinon', lexentry: 'fra/sinon__conjonction__1', trans_list: 'если не | иначе', score: 10 },
    { written_rep: 'que', lexentry: 'fra/que__conjonction__1', trans_list: 'что | чтобы', score: 90 },
    { written_rep: 'que', lexentry: 'fra/que__pronom_relatif__1', trans_list: 'кото́рый', score: 80 },
    { written_rep: 'vous-même', lexentry: 'fra/vous-même__pronom_personnel__1', trans_list: 'вы [[сам|са́ми]]', score: 5 },
    { written_rep: 'tiens', lexentry: null, trans_list: 'пожалуйста', score: 300 },
  ]);
  assert.equal(any.get('voiture'), 'машина, автомобиль, вагон');
  assert.equal(any.get('sinon'), 'если не, иначе');
  assert.equal(byPos.get('que').get('pronom_relatif'), 'который');
  assert.equal(byPos.get('que').get('conjonction'), 'что, чтобы');
  assert.equal(any.get('vous-même'), 'вы сами');
  assert.equal(any.has('tiens'), false);
});

test('lines join levels and translations and are sorted by bytes', () => {
  const text = serialize(new Map([['été', 'A1'], ['ami', 'A1']]), new Map([['ami', 'друг'], ['zèbre', 'зебра']]));
  assert.equal(text, 'ami\tA1\tдруг\nzèbre\t\tзебра\nété\tA1\t\n');
});
