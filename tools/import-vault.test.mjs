import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { buildLexicon, readingOf, serialize } from './build-lexicon.mjs';
import { importVault, parseRules, parseTexts, parseVocabulary, plainOf, tokenize } from './import-vault.mjs';

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

### Новая лексика урока

| Французское слово | Часть речи | Транскрипция | Перевод |
|---|---|---|---|
| \`l'ami\` | Существительное, мужской род | [lami] | ✎ друг |
| \`lire\` | Глагол III группы | [liʁ] | читать |
| \`joli, jolie\` | Прилагательное | [ʒɔli] | красивый, -ая |
| \`parler de qch\` | Глагол | [paʁle də] | говорить о чём-л. |
| \`le (la) secrétaire\` | Существительное | [lə (la) s(ə)kʁetɛʁ] | секретарь |

### Повторяющаяся лексика

| Французское слово | Часть речи | Транскрипция | Перевод |
|---|---|---|---|
| \`la\` | Артикль | [la] | артикль (урок 1) |

## Спряжение

### Lire — читать

| Лицо | Форма |
|---|---|
| je | lis |

**Особенности:** Во мн. ч. появляется [z].
`;

const TEXTS = `---
lesson: 3
---
# Урок 3. Тексты

> [!note] О транскрипции
> не входит в приложение

## Phrases

Фразы урока.

### 1. Marie lit. — Elle lit ?

**IPA:** [maʁi li] [ɛl li]

**Перевод:** Мари читает. — Она читает?

**Пояснение:**
- **lit** — конечное t не читается.

## Texte

**Français :** Les amis lisent.
**IPA:** [le‿zami liz]
**Перевод:** Друзья читают.

---

| | Français | IPA | Перевод |
|---|---|---|---|
| — | Il lit. | [il li] | Он читает. |

| Français | Перевод |
|---|---|
| il fait beau | хорошая погода |
`;

const RULES = `---
lesson: 3
---
# Урок 3. Правила

## Произношение

### Гласный [e]

Закрытый звук.

## Правила чтения

1. **s на конце слова** обычно не читается:
   *les amis*.
2. **t на конце слов** обычно не читается.

> В *les élèves* это **связывание**: конечный непроизносимый согласный становится произносимым.

## Грамматика

### 1. Глаголы I группы

Текст правила.

> [!warning] Частые ошибки
> - не забывайте *pas*.
`;

test('vocabulary: only the new words, with the remarks on conjugation', () => {
  const { words, verbNotes } = parseVocabulary(VOCABULARY);
  assert.deepEqual(words.map((word) => word.fr), ["l'ami", 'lire', 'joli, jolie', 'parler de qch', 'le (la) secrétaire']);
  assert.deepEqual(words[0], { fr: "l'ami", pos: 'Существительное, мужской род', ipa: 'lami', ru: 'друг' });
  assert.deepEqual(verbNotes, { lire: 'Во мн. ч. появляется [z].' });
});

test('texts: numbered phrases, labelled phrases and dialogue tables become sentences', () => {
  const [phrases, texte] = parseTexts(TEXTS);
  assert.equal(phrases.title, 'Phrases');
  assert.deepEqual(phrases.items.map((item) => (item.sentence ? 'sentence' : item.block.t)), ['p', 'sentence']);
  const { sentence } = phrases.items[1];
  assert.deepEqual([sentence.fr, sentence.ru], ['Marie lit. — Elle lit ?', 'Мари читает. — Она читает?']);
  assert.equal(sentence.note[0].t, 'list');
  assert.deepEqual(texte.items.map((item) => (item.sentence ? item.sentence.fr : item.block.t)), ['Les amis lisent.', 'Il lit.', 'table']);
  assert.equal(texte.items[1].sentence.speaker, '—');
});

test('rules: one per heading, plus the closing callout', () => {
  const rules = parseRules(RULES, 3);
  assert.deepEqual(rules.map((rule) => [rule.id, rule.kind, rule.title]), [
    ['3-1', 'Произношение', 'Гласный [e]'],
    ['3-2', 'Чтение', 'Правила чтения'],
    ['3-3', 'Грамматика', 'Глаголы I группы'],
    ['3-4', 'Примечания', 'Частые ошибки'],
  ]);
  assert.equal(rules[1].summary, 's на конце слова обычно не читается: les amis.');
});

test('punctuation stays with its word', () => {
  assert.deepEqual(tokenize('— Il lit ? « Oui » , dit-elle.'), ['— Il', 'lit ?', '« Oui » ,', 'dit-elle.']);
});

test('a whole vault: marks, sounds, glosses and links to reading rules', () => {
  const vault = mkdtempSync(join(tmpdir(), 'vault-'));
  const lesson = join(vault, 'Урок 3');
  mkdirSync(lesson);
  mkdirSync(join(vault, 'Урок 16')); // raw folder without front matter: skipped
  writeFileSync(join(vault, 'Урок 16', 'Дашборд.md'), '# Урок 16\n');
  writeFileSync(join(lesson, 'Дашборд.md'), '---\nlesson: 3\n---\n\n# Урок 3. Гласный [e]; глаголы I группы\n');
  writeFileSync(join(lesson, 'Слова.md'), VOCABULARY);
  writeFileSync(join(lesson, 'Тексты.md'), TEXTS);
  writeFileSync(join(lesson, 'Правила.md'), RULES);

  const { content, report } = importVault(vault, LEXIQUE);
  assert.equal(content.lessons.length, 1);
  const [three] = content.lessons;
  assert.deepEqual([three.id, three.topic], [3, 'Гласный [e]; глаголы I группы']);
  assert.deepEqual(three.words.map((word) => word.m), ["l'ami", 'lir(e)', 'joli, joli(e)', 'parle(r) de qch', undefined]);
  for (const word of three.words.filter((item) => item.m)) assert.equal(plainOf(word.m), word.fr);

  const tokens = three.sections[1].items[0].sentence.tokens;
  assert.deepEqual(tokens.map((token) => token.m), ['Le{s}', 'ami(s)', 'lis(ent).']);
  assert.deepEqual(tokens[1], { m: 'ami(s)', ipa: 'ami', link: 'z', tie: true, g: 'друг', r: 2 });
  assert.equal(content.readingRules[2].label, 'Связывание');
  assert.equal(tokens[2].g, 'читать'); // through the lemma
  assert.equal(content.readingRules[tokens[2].r].label, 't на конце слов обычно не читается');
  assert.deepEqual([report.sentences, report.alignedSentences], [3, 3]);
});

test('lexicon: the frequent reading first, schwa restored, lesson sound preferred, byte order', () => {
  assert.deepEqual(readingOf('ce', 'sø'), { marked: 'ce', ipa: 'sə' });
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
