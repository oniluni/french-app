'use strict';
// Lessons tab: lesson list, a lesson with its text, rules and words, a rule page, and notes.

const RULE_FORMS = ['правило', 'правила', 'правил'];
const NOTE_FORMS = ['заметка', 'заметки', 'заметок'];
const CARD_FORMS = ['карточка', 'карточки', 'карточек'];
const NOT_IN_PROTOTYPE = 'В прототипе тексты и правила заполнены для уроков 5 и 7. Слова есть во всех уроках.';

const lessonById = (id) => LESSONS.find((lesson) => lesson.id === id) ?? null;
const wordsOfLesson = (id) => WORDS.filter((word) => word.lesson === id);
const percent = (share) => `${Math.round(share * 100)} %`;

SCREENS.lessons = () => {
  const current = LESSONS.find((lesson) => lesson.progress > 0 && lesson.progress < 1) ?? LESSONS[0];
  const dueCount = WORDS.filter((word) => word.status === 'due').length;
  const openLesson = (lesson) => push({ name: 'lesson', id: lesson.id, seg: 'text' });
  return screenShell({ isRoot: true },
    h('h1', { class: 'large-title', text: 'Уроки' }),
    h('button', { class: 'hero', onclick: () => openLesson(current) },
      h('span', { class: 'hero-eyebrow', text: `Продолжить · урок ${current.id}` }),
      h('span', { class: 'hero-title', lang: 'fr', text: current.fr }),
      h('span', { class: 'hero-sub', text: current.ru }),
      h('span', { class: 'hero-foot' }, h('span', { class: 'bar', style: `--p:${current.progress * 100}` }), percent(current.progress))),
    h('div', { class: 'list' },
      h('button', { class: 'list-row', onclick: () => go('practice') },
        h('span', { class: 'row-main' },
          h('span', { text: `${plural(dueCount, CARD_FORMS)} к повторению` }),
          h('span', { class: 'row-sub', text: 'Сегодня · слова из пройденных уроков' })),
        icon('chevron'))),
    h('h2', { class: 'section', text: 'Все уроки' }),
    h('div', { class: 'list' }, LESSONS.map((lesson) =>
      h('button', { class: 'list-row', onclick: () => openLesson(lesson) },
        h('span', { class: 'ring', style: `--p:${lesson.progress * 100}`, 'aria-label': `Урок ${lesson.id}, пройдено ${percent(lesson.progress)}` }, String(lesson.id)),
        h('span', { class: 'row-main' },
          h('span', { class: 'row-fr', lang: 'fr', text: lesson.fr }),
          h('span', { class: 'row-sub', text: `${lesson.ru} · ${plural(wordsOfLesson(lesson.id).length, WORD_FORMS)}` })),
        icon('chevron')))));
};

SCREENS.lesson = (view) => {
  const lesson = lessonById(view.id);
  const hasText = view.seg === 'text' && TEXTS[lesson.id] !== undefined;
  const noteKey = `text-${lesson.id}`;
  const phoneticToggle = h('button', {
    class: 'gbtn glass', 'aria-pressed': String(state.isPhonetic), 'aria-label': 'Показать произношение',
    onclick: () => {
      state.isPhonetic = !state.isPhonetic;
      show('none', { keepScroll: true });
    },
  }, '[ə]');
  const body = { text: lessonText, rules: lessonRules, words: lessonWords }[view.seg](lesson);
  return screenShell({
    title: `Урок ${lesson.id}`,
    actions: hasText ? [phoneticToggle] : [],
    fab: hasText ? notesFab(noteKey, `Урок ${lesson.id} · текст`) : null,
  },
  h('h1', { class: 'lesson-title', lang: 'fr', text: lesson.fr }),
  h('p', { class: 'lesson-sub', text: lesson.ru }),
  segmented([['text', 'Текст'], ['rules', 'Правила'], ['words', 'Слова']], view.seg, (seg) => {
    view.seg = seg;
    show('none');
  }),
  body);
};

function lessonText(lesson) {
  const text = TEXTS[lesson.id];
  if (!text) return h('p', { class: 'empty', text: NOT_IN_PROTOTYPE });
  const noteKey = `text-${lesson.id}`;
  const words = flattenSentences(text.sentences);
  const notedRanges = (state.notes[noteKey] ?? []).filter((note) => note.range).map((note) => note.range);
  const box = renderWords(words, notedRanges);
  box.classList.toggle('is-phonetic', state.isPhonetic);
  attachSelection(box, (a, b) => openWordPopover({
    box, words, sentences: text.sentences, a, b, lessonId: lesson.id, noteKey, noteLabel: `Урок ${lesson.id} · текст`,
  }));
  const fullText = text.sentences.map(sentenceText).join(' ');
  return h('article', { class: 'card' },
    h('button', { class: 'inline-play', onclick: () => speak(fullText) }, icon('speaker'), 'Прослушать текст'),
    box,
    h('p', { class: 'hint', text: 'Нажмите на слово, чтобы увидеть транскрипцию и перевод. Чтобы выбрать фразу, задержите палец и проведите по словам. Кнопка [ə] вверху показывает немые буквы и связывания.' }));
}

function lessonRules(lesson) {
  const rules = RULES.filter((rule) => rule.lesson === lesson.id);
  if (rules.length === 0) return h('p', { class: 'empty', text: NOT_IN_PROTOTYPE });
  return h('div', { class: 'list' }, rules.map((rule) =>
    h('button', { class: 'list-row', onclick: () => push({ name: 'rule', id: rule.id }) },
      h('span', { class: 'row-main' },
        h('span', { class: 'row-sub', text: rule.kind }),
        h('span', { text: rule.title }),
        h('span', { class: 'row-sub', text: rule.short })),
      icon('chevron'))));
}

function lessonWords(lesson) {
  return [
    h('button', { class: 'btn-primary', onclick: () => startRange(lesson.id, lesson.id) }, 'Учить слова урока'),
    h('div', { class: 'list' }, wordsOfLesson(lesson.id).map(wordRow)),
  ];
}

SCREENS.rule = (view) => {
  const rule = RULES.find((item) => item.id === view.id);
  return screenShell({ title: `Урок ${rule.lesson}`, fab: notesFab(`rule-${rule.id}`, rule.title) },
    h('span', { class: 'tag', text: rule.kind }),
    h('h1', { class: 'rule-title', text: rule.title }),
    rule.body.map((paragraph) => h('p', { class: 'prose', text: paragraph })),
    rule.table ? ruleTable(rule.table) : null,
    h('h2', { class: 'section', text: 'Примеры' }),
    h('div', { class: 'list' }, rule.examples.map(exampleRow)));
};

function ruleTable({ head, cols, rows }) {
  const cell = (value, kind) => {
    if (kind === 'fr') return h('td', { class: 'fr', lang: 'fr' }, marked(value));
    if (kind === 'ipa') return h('td', {}, ipa(value));
    return h('td', { text: value });
  };
  return h('div', { class: 'table-wrap' },
    h('table', {},
      h('thead', {}, h('tr', {}, head.map((label) => h('th', { scope: 'col', text: label })))),
      h('tbody', {}, rows.map((row) => h('tr', {}, row.map((value, i) => cell(value, cols[i])))))));
}

function exampleRow(raw) {
  const [fr, ipaText, ru] = raw.split('|');
  const plain = plainOf(fr);
  return h('button', { class: 'list-row', 'aria-label': `Прослушать: ${plain}`, onclick: () => speak(plain) },
    h('span', { class: 'row-main' }, h('span', { class: 'row-fr', lang: 'fr' }, marked(fr)), h('span', { class: 'row-sub', text: ru })),
    ipa(ipaText),
    icon('speaker'));
}

// --- Notes ---

function notesFab(key, label) {
  const count = state.notes[key]?.length ?? 0;
  return h('button', { class: 'fab glass', 'aria-label': `Заметки: ${plural(count, NOTE_FORMS)}`, onclick: () => openNotes(key, label) },
    icon('note'),
    count > 0 ? h('span', { class: 'badge', text: String(count) }) : null);
}

/** Notes sheet for one screen. `anchor` ties the next note to a text fragment: { quote, range }. */
function openNotes(key, label, anchor = null) {
  const list = h('div', { class: 'notes' });
  const quote = anchor ? h('p', { class: 'note-quote', lang: 'fr', text: anchor.quote }) : null;
  const input = h('textarea', { id: 'note-input', class: 'note-input', rows: '3', placeholder: 'Что хотите запомнить?', 'aria-label': 'Новая заметка' });
  const saveButton = h('button', { class: 'btn-primary', disabled: true, onclick: save }, 'Сохранить');

  const paint = () => {
    const notes = state.notes[key] ?? [];
    list.replaceChildren(...(notes.length > 0
      ? notes.map((note) => h('div', { class: 'note' },
        note.quote ? h('p', { class: 'note-quote', lang: 'fr', text: note.quote }) : null,
        h('p', { class: 'note-text', text: note.text })))
      : [h('p', { class: 'caption', text: 'Пока нет заметок. Запишите то, что хотите запомнить отсюда.' })]));
  };
  function save() {
    state.notes[key] ??= [];
    state.notes[key].push({ text: input.value.trim(), quote: anchor?.quote ?? '', range: anchor?.range ?? null });
    anchor = null;
    quote?.remove();
    input.value = '';
    saveButton.disabled = true;
    paint();
    show('none', { keepScroll: true }); // refreshes the badge and the highlight behind the sheet
  }
  input.addEventListener('input', () => { saveButton.disabled = input.value.trim() === ''; });

  paint();
  openSheet('Заметки', [
    h('div', { class: 'sheet-head' },
      h('div', {}, h('h2', { class: 'sheet-title', text: 'Заметки' }), h('p', { class: 'caption', text: label })),
      h('button', { class: 'text-btn', onclick: () => closeSheet() }, 'Готово')),
    list, quote, input, saveButton,
  ]);
  if (anchor) input.focus();
}
