'use strict';
// "Разбор" tab: the reader (how a phrase is pronounced) and the word analysis (how a word changes).

const LETTER_FORMS = ['буква не читается', 'буквы не читаются', 'букв не читаются'];
const LIAISON_FORMS = ['связывание', 'связывания', 'связываний'];
const NASAL_FORMS = ['носовой звук', 'носовых звука', 'носовых звуков'];
const WORD_EXAMPLES = ['buvons', 'parlent', 'étais', 'petites', 'enfants', 'chère'];

const normalizePhrase = (text) => text.trim().toLowerCase().replace(/[.!?\s]+$/, '').replace(/\s+/g, ' ');

SCREENS.tools = () => {
  const { seg } = state.tools;
  return screenShell({ isRoot: true },
    h('h1', { class: 'large-title', text: 'Разбор' }),
    segmented([['reader', 'Читалка'], ['word', 'Слово']], seg, (next) => {
      state.tools.seg = next;
      show('none');
    }),
    seg === 'reader' ? readerTool() : wordTool());
};

// --- Reader ---

function readerTool() {
  const tools = state.tools;
  tools.text ??= sentenceText(READER_SAMPLES[0]);
  const sample = READER_SAMPLES[tools.sample] ?? null;
  const analyse = (event) => {
    event.preventDefault();
    tools.sample = READER_SAMPLES.findIndex((item) => normalizePhrase(sentenceText(item)) === normalizePhrase(tools.text));
    show('none', { keepScroll: true });
  };
  const input = h('textarea', {
    id: 'reader-input', class: 'field', rows: '2', lang: 'fr', 'aria-label': 'Французская фраза',
    oninput: (event) => { tools.text = event.target.value; },
  });
  input.value = tools.text;

  return [
    h('p', { class: 'caption', text: 'Введите фразу и посмотрите, как она читается: какие буквы молчат и где слова связываются.' }),
    h('form', { class: 'card', onsubmit: analyse }, input, h('button', { class: 'btn-primary', type: 'submit' }, 'Разобрать')),
    sample ? readerResult(sample) : h('p', { class: 'notice', text: 'Прототип разбирает только три фразы из списка ниже. В приложении здесь появится разбор любого текста.' }),
    h('div', { class: 'card' },
      legendRow('parl(ent)', 'Бледные буквы с точками не читаются'),
      legendRow('le{s}‿ami(s)', 'Дужка: слова связываются, согласная звучит'),
      legendRow('mat[in]', 'Подложка: носовой гласный')),
    h('h2', { class: 'section', text: 'Примеры' }),
    h('div', { class: 'list' }, READER_SAMPLES.map((item, index) =>
      h('button', {
        class: 'list-row',
        onclick: () => {
          tools.text = sentenceText(item);
          tools.sample = index;
          show('none');
        },
      },
      h('span', { class: 'row-main' },
        h('span', { class: 'row-fr', lang: 'fr', text: sentenceText(item) }),
        h('span', { class: 'row-sub', text: item.ru })),
      index === tools.sample ? icon('check') : null))),
  ];
}

function legendRow(sample, meaning) {
  return h('div', { class: 'legend-row' }, h('span', { class: 'row-fr', lang: 'fr' }, marked(sample)), h('span', { class: 'row-sub', text: meaning }));
}

function readerResult(sample) {
  const words = flattenSentences([sample]);
  const box = renderWords(words);
  box.classList.add('is-phonetic');
  attachSelection(box, (a, b) => openWordPopover({ box, words, sentences: [sample], a, b }));

  const silentLetters = words.reduce((sum, word) => sum + lettersOf(word.src, 'silent').join('').length, 0);
  const nasals = words.reduce((sum, word) => sum + lettersOf(word.src, 'nasal').length, 0);
  const liaisons = words.filter((word) => word.link).length;
  const stat = (count, forms) => h('div', { class: 'stat' }, h('b', { text: String(count) }), h('span', { text: pluralForm(count, forms) }));

  return [
    h('div', { class: 'card' },
      box,
      h('div', { class: 'result-foot' },
        h('div', { class: 'row-main' }, ipa(phraseIpa(words, 0, words.length - 1)), h('span', { class: 'row-sub', text: sample.ru })),
        speakButton(sentenceText(sample)))),
    h('div', { class: 'stats' }, stat(silentLetters, LETTER_FORMS), stat(liaisons, LIAISON_FORMS), stat(nasals, NASAL_FORMS)),
  ];
}

// --- Word analysis ---

function wordTool() {
  const holder = state.tools.word;
  const input = h('input', {
    id: 'word-input', class: 'field', type: 'text', lang: 'fr', value: holder.query,
    autocomplete: 'off', autocapitalize: 'none', spellcheck: 'false', 'aria-label': 'Слово в любой форме',
  });
  const lookUp = (query) => {
    holder.query = query;
    holder.set = null;
    show('none');
  };
  return [
    h('p', { class: 'caption', text: 'Введите слово в любой форме. Покажем начальную форму, род, число и как слово изменяется.' }),
    h('form', {
      class: 'card',
      onsubmit: (event) => {
        event.preventDefault();
        lookUp(input.value);
      },
    }, input, h('button', { class: 'btn-primary', type: 'submit' }, 'Разобрать')),
    h('div', { class: 'chips is-wrap', role: 'group', 'aria-label': 'Примеры слов' },
      WORD_EXAMPLES.map((example) => chip(example, lastWord(holder.query) === example, () => lookUp(example)))),
    wordAnalysis(holder),
  ];
}
