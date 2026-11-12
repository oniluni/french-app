import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseBlocks, plainText } from './markdown.mjs';

test('headings, paragraphs and rules', () => {
  assert.deepEqual(parseBlocks('## Грамматика\n\nПервая строка\nвторая строка\n\n---\n\nДругой абзац'), [
    { t: 'h', level: 2, md: 'Грамматика' },
    { t: 'p', md: 'Первая строка\nвторая строка' },
    { t: 'hr' },
    { t: 'p', md: 'Другой абзац' },
  ]);
});

test('a list item keeps its continuation lines and nested blocks', () => {
  const [list] = parseBlocks([
    '1. **f на конце слов** читается:',
    '   *neuf* [nœf], *actif*.',
    '2. **r на конце слова** обычно читается:',
    '   *la fleur*.',
    '   **r не читается:**',
    '   - в окончании **-er**;',
    '   - в словах на **-ier**.',
  ].join('\n'));
  assert.equal(list.ordered, true);
  assert.equal(list.items.length, 2);
  assert.equal(list.items[0].md, '**f на конце слов** читается:\n*neuf* [nœf], *actif*.');
  assert.deepEqual(list.items[0].blocks, []);
  assert.deepEqual(list.items[1].blocks, [{
    t: 'list', ordered: false,
    items: [{ md: 'в окончании **-er**;', blocks: [] }, { md: 'в словах на **-ier**.', blocks: [] }],
  }]);
});

test('a label line directly above a list is its own paragraph', () => {
  const blocks = parseBlocks('**Пояснение:**\n- раз\n- два\n\nПосле списка');
  assert.deepEqual(blocks.map((block) => block.t), ['p', 'list', 'p']);
  assert.equal(blocks[1].items.length, 2);
});

test('blank lines between items do not split a list', () => {
  const [list, ...rest] = parseBlocks('1. раз\n\n2. два\n\n3. три');
  assert.equal(list.items.length, 3);
  assert.deepEqual(rest, []);
});

test('tables', () => {
  assert.deepEqual(parseBlocks('| Лицо | Форма |\n|---|---|\n| je | vais |\n| tu | vas |'), [
    { t: 'table', head: ['Лицо', 'Форма'], rows: [['je', 'vais'], ['tu', 'vas']] },
  ]);
});

test('callouts hold blocks of their own', () => {
  const [callout] = parseBlocks('> [!warning] Частые ошибки\n> - **Элизия обязательна:**\n>   - читается *fleur*;\n> - второе\n>\n> Абзац.');
  assert.equal(callout.kind, 'warning');
  assert.equal(callout.title, 'Частые ошибки');
  assert.deepEqual(callout.blocks.map((block) => block.t), ['list', 'p']);
  assert.equal(callout.blocks[0].items[0].blocks[0].items[0].md, 'читается *fleur*;');
});

test('vault links and comments are removed', () => {
  assert.deepEqual(parseBlocks('См. [[Урок 5/Тексты|Тексты]] и [[Правила]].\n\n%%\n#flashcards\nse lever::вставать\n%%'), [
    { t: 'p', md: 'См. Тексты и Правила.' },
  ]);
});

test('plain text for summaries', () => {
  assert.equal(plainText('**j** читается [ʒ]:\n*je* `déjeune` ~~нет~~'), 'j читается [ʒ]: je déjeune нет');
});
