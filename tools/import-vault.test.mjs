import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { buildLexicon, lessonReadings, readingOf, serialize } from './build-lexicon.mjs';
import { importVault, parseRules, parseVocabulary, plainOf } from './import-vault.mjs';
import { attachTriggers } from './rule-triggers.mjs';

const row = (ortho, ipa, lemma, pos, extra = {}) => ({ ortho, ipa, lemma, pos, gender: '', number: '', tags: [], frequency: 1, ...extra });
const LEXIQUE = [
  row('les', 'le', 'les', 'ART:def', { number: 'p', frequency: 900 }),
  row('amis', 'ami', 'ami', 'NOM', { gender: 'm', number: 'p' }),
  row('ami', 'ami', 'ami', 'NOM', { gender: 'm', number: 's' }),
  row('lit', 'li', 'lire', 'VER', { tags: ['ind:pre:3s'], frequency: 5 }),
  row('lit', 'li', 'lit', 'NOM', { gender: 'm', number: 's', frequency: 50 }),
  row('lire', 'liʁ', 'lire', 'VER', { tags: ['inf'] }),
  row('lisent', 'liz', 'lire', 'VER', { tags: ['ind:pre:3p'] }),
  row('ce', 'sø', 'ce', 'ADJ:dem'),
  row('deux', 'dø', 'deux', 'ADJ:num'),
];

const VOCABULARY = `---
lesson: 3
---
# Урок 3. Словарь

## Словарь урока

### Существительные

| Слово | Произношение | Перевод | Грамматика |
|---|---|---|---|
| **l'ami** | [lami] | ✎ друг | существительное, м. р. |
| **le (la) secrétaire** | [lə (la) s(ə)kʁetɛʁ] | секретарь | существительное |

### Глаголы и прочее

| Слово | Произношение | Перевод | Грамматика |
|---|---|---|---|
| **lire** | [liʁ] | читать | глагол III группы |
| **joli, jolie** | [ʒɔli] | красивый, -ая | прилагательное |
| **seul, seule** | [sœl] | один, одна | прилагательное |
| **parler de qch** | [paʁle də] | говорить о чём-л. | глагол |
| **\*haut** | [o] | высокий | прилагательное |

### Повторяющаяся лексика

| Слово | Произношение | Перевод | Грамматика |
|---|---|---|---|
| **la** | [la] | артикль (урок 1) | артикль |

## Спряжение глаголов III группы в Présent

### Lire — читать

| Лицо | Форма |
|---|---|
| je | lis |

**Особенности:** Во мн. ч. появляется [z].

%%
#flashcards
l'ami::друг
%%
`;

const RULES = `---
lesson: 3
---
# Урок 3. Правила

> [!note] Транскрипция
> не входит в приложение

## Произношение

| Звук | Как произносить | Отличие от [ɛ] |
|---|---|---|
| **[e]** | Закрытый звук. | Рот закрыт сильнее. |

### Как пишется [e]

| Написание | Где | Пример |
|---|---|---|
| **é** | везде | *armée* |

## Правила чтения

| Написание | Читается | Пример |
|---|---|---|
| **s** на конце слова | обычно не читается | *très* |
| **t** на конце слова | обычно не читается | *elle part* |
| **ch** | [ʃ] | *chaise* |
| **c** на конце после согласного | [k] | *parc* |

**Связывание** (liaison). Конечный немой согласный звучит перед гласным: *les‿amis*.

## Грамматика

### 1. Глаголы I группы

Текст правила.

## Комментарии к словам

| Слово | Что важно |
|---|---|
| chez | только с лицами |

> [!warning] Исключения и частые ошибки
> - не забывайте *pas*.
`;

test('vocabulary: every table of the lesson dictionary but the repeated words, with the remarks on conjugation', () => {
  const { words, verbNotes } = parseVocabulary(VOCABULARY);
  assert.deepEqual(words.map((word) => word.fr), ["l'ami", 'le (la) secrétaire', 'lire', 'joli, jolie', 'seul, seule', 'parler de qch', '*haut']);
  assert.deepEqual(words[0], { fr: "l'ami", pos: 'существительное, м. р.', ipa: 'lami', ru: 'друг' });
  assert.deepEqual(verbNotes, { lire: 'Во мн. ч. появляется [z].' });
  assert.throws(() => parseVocabulary('# Урок 3. Словарь\n'), /«Словарь урока»/);
});

test('rules: one per heading with text of its own, plus the closing callout; the sounds name the first', () => {
  const rules = parseRules(RULES, 3);
  assert.deepEqual(rules.map((rule) => [rule.id, rule.kind, rule.title]), [
    ['3-r1', 'Произношение', 'Звук [e]'],
    ['3-r2', 'Произношение', 'Как пишется [e]'],
    ['3-r3', 'Чтение', 'Правила чтения'],
    ['3-r4', 'Грамматика', 'Глаголы I группы'],
    ['3-r5', 'Примечания', 'Комментарии к словам'],
    ['3-r6', 'Примечания', 'Исключения и частые ошибки'],
  ]);
  assert.equal(rules[3].summary, 'Текст правила.');
});

test('rules: a long summary keeps whole sentences, else whole words', () => {
  const summary = (text) => parseRules(`## Грамматика\n\n### Правило\n\n${text}\n`, 4)[0].summary;
  const first = 'Притяжательные ma, ta, sa и указательное cette вместе называются местоимёнными прилагательными.';
  assert.equal(summary(`${first} Это служебные слова, они не несут ударения и стоят перед существительным.`), first);
  const long = 'Связывание: конечный немой согласный звучит, если следующее слово в той же ритмической группе начинается с гласного или немого h';
  assert.equal(summary(long), 'Связывание: конечный немой согласный звучит, если следующее слово в той же ритмической группе начинается с…');
});

test('a whole vault: marks on the words, triggers, and reading rules from the table rows', () => {
  const vault = mkdtempSync(join(tmpdir(), 'vault-'));
  const lesson = join(vault, 'Урок 3');
  mkdirSync(lesson);
  mkdirSync(join(vault, 'Урок 16')); // raw folder without front matter: skipped
  writeFileSync(join(vault, 'Урок 16', 'Дашборд.md'), '# Урок 16\n');
  writeFileSync(join(lesson, 'Дашборд.md'), '---\nlesson: 3\n---\n\n# Урок 3. Гласный [e]; глаголы I группы\n');
  writeFileSync(join(lesson, 'Слова.md'), VOCABULARY);
  writeFileSync(join(lesson, 'Правила.md'), RULES);

  const triggers = {
    '3-r1': { title: 'Звук [e]', trigger: { ipa: ['e'] } },
    '3-r2': { title: 'Как пишется [e]', trigger: { ipa: ['e'] } },
    '3-r4': { title: 'Глаголы I группы', trigger: { token: { group: 1 } } },
  };
  const { content } = importVault(vault, LEXIQUE, { triggers });
  assert.equal(content.lessons.length, 1);
  const [three] = content.lessons;
  assert.deepEqual([three.id, three.topic, three.sections], [3, 'Гласный [e]; глаголы I группы', undefined]);
  assert.deepEqual(three.rules.map((rule) => rule.trigger ?? null), [{ ipa: ['e'] }, { ipa: ['e'] }, null, { token: { group: 1 } }, null, null]);
  assert.deepEqual(three.words.map((word) => word.m), ["l'ami", undefined, 'lir(e)', 'joli, joli(e)', 'seul, seul(e)', 'parle(r) de qch', '*(h)au(t)']);
  for (const word of three.words.filter((item) => item.m)) assert.equal(plainOf(word.m), word.fr);

  assert.deepEqual(content.readingRules.map(({ rule, label, pattern }) => [rule, label, pattern]), [
    ['3-r3', 's на конце слова — обычно не читается', { kind: 'silent-final', letter: 's' }],
    ['3-r3', 't на конце слова — обычно не читается', { kind: 'silent-final', letter: 't' }],
    ['3-r3', 'ch — [ʃ]', { kind: 'sound', letters: 'ch', sound: 'ʃ' }],
    ['3-r3', 'c на конце после согласного — [k]', { kind: 'heard-final', letter: 'c' }],
    ['3-r3', 'Связывание', { kind: 'liaison' }],
  ]);
});

test('lexicon: the frequent reading first, schwa restored, lesson sound preferred, byte order', () => {
  assert.deepEqual(readingOf('ce', 'sø'), { marked: 'ce', ipa: 'sə' });
  const said = lessonReadings({ lessons: [{ words: [{ fr: 'seul, seule', ipa: 'sœl', m: 'seul, seul(e)' }] }] });
  assert.deepEqual([said.get('seul'), said.get('seule')], [{ marked: 'seul', ipa: 'sœl' }, { marked: 'seul(e)', ipa: 'sœl' }]);
  assert.deepEqual(readingOf('deux', 'dø'), { marked: 'deu(x)', ipa: 'dø' });

  const built = buildLexicon(LEXIQUE, new Map([['denise', { marked: 'Denis(e)', ipa: 'dəniz' }], ['les', { marked: 'le(s)', ipa: 'lɛ' }]]));
  assert.deepEqual(built.lexicon.get('lit'), { readings: [{ marked: 'li(t)', ipa: 'li' }], analyses: ['lit;NOM;m;s;;0', 'lire;VER;;;ind:pre:3s;0'] });
  assert.deepEqual(built.lexicon.get('les').readings, [{ marked: 'le(s)', ipa: 'lɛ' }]);
  assert.deepEqual(built.lexicon.get('denise'), { readings: [{ marked: 'Denis(e)', ipa: 'dəniz' }], analyses: [] });
  assert.deepEqual(built.lemmas.get('lire\tV'), { lemma: 'lire', forms: ['lit;;;ind:pre:3s', 'lire;;;inf', 'lisent;;;ind:pre:3p'] });

  const { lexicon } = serialize(built);
  const keys = lexicon.trim().split('\n').map((line) => line.split('\t')[0]);
  assert.deepEqual(keys, [...keys].sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b))));
  assert.ok(lexicon.includes('lit\tli(t)=li\tlit;NOM;m;s;;0|lire;VER;;;ind:pre:3s;0\n'));
});

test('every rule needs a trigger with the right title, so a changed vault fails the import', () => {
  const lessons = () => [{ rules: [
    { id: '3-1', kind: 'Произношение', title: 'Гласный [e]' },
    { id: '3-2', kind: 'Чтение', title: 'Правила чтения' },
    { id: '3-3', kind: 'Примечания', title: 'Частые ошибки' },
  ] }];
  const itemized = [{ rule: '3-2' }];
  assert.throws(() => attachTriggers(lessons(), itemized, {}), /3-1 «Гласный \[e\]»/);
  assert.throws(() => attachTriggers(lessons(), itemized, { '3-1': { title: 'Гласный [a]', trigger: {} } }), /now «Гласный \[e\]»/);
  const done = lessons();
  attachTriggers(done, itemized, { '3-1': { title: 'Гласный [e]', trigger: { ipa: ['e'] } } });
  assert.deepEqual(done[0].rules[0].trigger, { ipa: ['e'] });
});
