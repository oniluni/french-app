import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildExamples, lemmasOf, lessonExamples, serialize, tatoebaPairs, wordsOf } from './build-examples.mjs';
import { indexByForm } from './lexique.mjs';

const row = (ortho, lemma, pos, frequency = 1) => ({ ortho, ipa: '', lemma, pos, gender: '', number: '', tags: [], frequency });
const byKey = indexByForm([
  row('ami', 'ami', 'NOM'), row('amie', 'ami', 'NOM'), row('amis', 'ami', 'NOM'),
  row('va', 'aller', 'VER'), row('il', 'il', 'PRO:per'), row('chez', 'chez', 'PRE'),
  row('bus', 'bus', 'NOM', 40), row('bus', 'boire', 'VER', 0.5),
]);

test('words split elision and hyphen', () => {
  assert.deepEqual(wordsOf("L'amie va-t-elle chez Paul ?"), ['amie', 'va', 't', 'elle', 'chez', 'paul']);
});

test('a sentence contains the lemmas of its forms', () => {
  assert.deepEqual([...lemmasOf("Il va chez son amie.", byKey)].sort(), ['aller', 'ami', 'chez', 'il']);
});

test('a rare reading of a form does not make the sentence an example of its lemma', () => {
  assert.deepEqual([...lemmasOf('Le bus', byKey)], ['bus']);
});

test('Tatoeba pairs: linked, translated, and of a readable length', () => {
  const fra = '1\tfra\tBonjour.\n2\tfra\tMon amie va à Paris demain.\n3\tfra\tJe vais chez mon ami ce soir.\n';
  const rus = '10\trus\tМоя подруга едет в Париж завтра.\n11\trus\tЯ иду к другу вечером.\n12\trus\tЗдравствуйте.\n';
  const links = '1\t12\n2\t10\n3\t11\n3\t10\n4\t10\n';
  assert.deepEqual(tatoebaPairs(fra, rus, links), [
    { fr: 'Mon amie va à Paris demain.', ru: 'Моя подруга едет в Париж завтра.', src: 'T2' },
    { fr: 'Je vais chez mon ami ce soir.', ru: 'Я иду к другу вечером.', src: 'T3' },
  ]);
});

test('lesson phrases keep their marks only when every word has them', () => {
  const content = { lessons: [{ id: 5, sections: [{ items: [
    { sentence: { ru: 'Друзья', tokens: [{ m: 'Le{s}' }, { m: 'ami(s).', tie: true }] } },
    { sentence: { ru: 'Нравится', tokens: [{ m: 'il' }, { t: '(te)' }] } },
    { block: { t: 'p', md: 'текст' } },
  ] }] }] };
  assert.deepEqual(lessonExamples(content), [
    { fr: 'Les amis.', m: 'Le{s}‿ami(s).', ru: 'Друзья', src: 'L5' },
    { fr: 'il (te)', ru: 'Нравится', src: 'L5' },
  ]);
});

test('lessons come first, then Tatoeba closest to the ideal length, byte-sorted lines', () => {
  const lesson = [{ fr: 'Les amis.', ru: 'Друзья.', src: 'L5' }];
  const pairs = [
    { fr: 'Mon ami va à Paris.', ru: 'Мой друг едет в Париж.', src: 'T1' },
    { fr: 'Il va chez un ami qui habite très loin de la ville, au bord de la mer.', ru: 'Он едет к другу у моря.', src: 'T2' },
    { fr: 'Il va chez son ami ce soir après le travail.', ru: 'Он идёт к другу вечером.', src: 'T3' },
    { fr: 'Ami, va !', ru: 'Иди, друг!', src: 'T4' },
    { fr: 'Mon amie va bien, merci.', ru: 'У подруги всё хорошо.', src: 'T5' },
    { fr: 'Mon amie se porte bien, merci.', ru: 'У подруги всё хорошо.', src: 'T6' },
  ];
  const lines = buildExamples(lesson, pairs, byKey);
  // T5 and T6 share a translation: only T6 stays, being closer to the ideal length (30 vs 24 chars).
  assert.deepEqual(lines.get('ami').map((example) => example.src), ['L5', 'T3', 'T6', 'T1']);
  const keys = serialize(lines).trim().split('\n').map((line) => line.split('\t')[0]);
  assert.deepEqual(keys, [...keys].sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b))));
});
