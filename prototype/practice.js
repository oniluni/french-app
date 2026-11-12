'use strict';
// Practice tab: word cards by lesson range (Anki-style session) and the list of form drills.

const SESSION_SIZE = 10;
const REVIEW_ORDER = { due: 0, new: 1, learning: 2, known: 3 };
// Intervals are fixed labels: the prototype has no scheduling algorithm.
const GRADES = [
  { id: 'again', label: 'Снова', wait: '< 1 мин', next: null },
  { id: 'hard', label: 'Трудно', wait: '6 мин', next: 'learning' },
  { id: 'good', label: 'Хорошо', wait: '1 день', next: 'known' },
  { id: 'easy', label: 'Легко', wait: '4 дня', next: 'known' },
];

const wordsInRange = (from, to) => WORDS.filter((word) => word.lesson >= from && word.lesson <= to);
const rangeTitle = (from, to) => (from === to ? `Урок ${from}` : `Уроки ${from}–${to}`);

SCREENS.practice = () => {
  const { seg } = state.practice;
  return screenShell({ isRoot: true },
    h('h1', { class: 'large-title', text: 'Практика' }),
    segmented([['words', 'Слова'], ['forms', 'Формы']], seg, (next) => {
      state.practice.seg = next;
      show('none');
    }),
    seg === 'words' ? practiceWords() : practiceForms());
};

function practiceWords() {
  const due = WORDS.filter((word) => word.status === 'due');
  const { from, to } = state.range;
  const end = to ?? from;
  const pickLesson = (id) => {
    const isFresh = from === null || to !== null;
    state.range = isFresh ? { from: id, to: null } : { from: Math.min(from, id), to: Math.max(from, id) };
    show('none', { keepScroll: true });
  };
  const chipClass = (id) => {
    if (from === null || id < from || id > end) return 'lesson-chip';
    return `lesson-chip in-range${id === from ? ' is-from' : ''}${id === end ? ' is-to' : ''}`;
  };
  const summary = from === null
    ? 'Уроки не выбраны'
    : `${rangeTitle(from, end)} · ${plural(wordsInRange(from, end).length, WORD_FORMS)}`;

  return [
    h('div', { class: 'hero' },
      h('span', { class: 'hero-eyebrow', text: 'Сегодня' }),
      h('span', { class: 'hero-number', text: String(due.length) }),
      h('span', { class: 'hero-sub', text: `${pluralForm(due.length, CARD_FORMS)} к повторению` }),
      h('button', { class: 'hero-btn', disabled: due.length === 0, onclick: () => beginSession('Сегодня', due, '') }, 'Повторить')),
    h('h2', { class: 'section', text: 'Новый набор' }),
    h('div', { class: 'card' },
      h('p', { class: 'caption', text: 'Отметьте первый и последний урок. Набор сохранится, и к нему можно будет вернуться.' }),
      h('div', { class: 'lesson-grid', role: 'group', 'aria-label': 'Уроки' }, LESSONS.map((lesson) =>
        h('button', { class: chipClass(lesson.id), 'aria-label': `Урок ${lesson.id}`, onclick: () => pickLesson(lesson.id) }, String(lesson.id)))),
      h('div', { class: 'range-summary' },
        h('span', { text: summary }),
        h('button', { class: 'btn-primary', disabled: from === null, onclick: () => startRange(from, end) }, 'Начать'))),
    h('h2', { class: 'section', text: 'Мои наборы' }),
    h('div', { class: 'list' }, state.sets.map(setRow)),
  ];
}

function setRow(set) {
  const words = wordsInRange(set.from, set.to);
  const known = words.filter((word) => word.status === 'known').length;
  const due = words.filter((word) => word.status === 'due').length;
  return h('button', { class: 'list-row', onclick: () => startRange(set.from, set.to) },
    h('span', { class: 'ring', style: `--p:${(known / words.length) * 100}`, 'aria-hidden': 'true' }),
    h('span', { class: 'row-main' },
      h('span', { text: rangeTitle(set.from, set.to) }),
      h('span', { class: 'row-sub', text: `Выучено ${known} из ${words.length}${due > 0 ? ` · повторить ${due}` : ''}` })),
    icon('chevron'));
}

function practiceForms() {
  const { tense } = state.practice;
  const verbs = ANALYSIS.filter((entry) => entry.kind === 'verb');
  const others = ANALYSIS.filter((entry) => entry.kind !== 'verb');
  const tenses = [...new Set(verbs.flatMap((entry) => entry.sets.map((set) => set.name)))];
  const setTense = (next) => {
    state.practice.tense = next;
    show('none', { keepScroll: true });
  };
  const drillRow = (entry, title, setName) =>
    h('button', { class: 'list-row', onclick: () => startDrill(title, [entry], setName) },
      h('span', { class: 'row-main' },
        h('span', { class: 'row-fr', lang: 'fr', text: entry.lemma }),
        h('span', { class: 'row-sub', text: `${findWord(entry.lemma)?.ru ?? ''} · ${KIND_LABELS[entry.kind]}` })),
      icon('chevron'));

  return [
    h('div', { class: 'hero' },
      h('span', { class: 'hero-eyebrow', text: 'Все темы' }),
      h('span', { class: 'hero-heading', text: 'Смешанная тренировка' }),
      h('span', { class: 'hero-sub', text: `${plural(DRILL_SIZE, QUESTION_FORMS)}: спряжения, род и число` }),
      h('button', { class: 'hero-btn', onclick: () => startDrill('Смешанная тренировка', ANALYSIS) }, 'Начать')),
    h('h2', { class: 'section', text: 'Спряжения' }),
    h('div', { class: 'chips', role: 'group', 'aria-label': 'Время' },
      chip('Все', tense === null, () => setTense(null)),
      tenses.map((name) => chip(name, tense === name, () => setTense(name)))),
    h('div', { class: 'list' }, verbs.map((entry) => drillRow(entry, tense ? `${entry.lemma} · ${tense}` : entry.lemma, tense))),
    h('h2', { class: 'section', text: 'Род и число' }),
    h('div', { class: 'list' }, others.map((entry) => drillRow(entry, entry.lemma, null))),
  ];
}

// --- Card session ---

/** Starts a session for a lesson range and keeps the range as a saved set. */
function startRange(from, to) {
  if (!state.sets.some((set) => set.from === from && set.to === to)) state.sets.unshift({ from, to });
  state.range = { from: null, to: null };
  beginSession(rangeTitle(from, to), wordsInRange(from, to), 'Набор сохранён в «Моих наборах».');
}

function beginSession(title, pool, doneNote) {
  const queue = [...pool].sort((a, b) => REVIEW_ORDER[a.status] - REVIEW_ORDER[b.status]).slice(0, SESSION_SIZE);
  if (queue.length === 0) {
    toast('В этих уроках пока нет слов');
    return;
  }
  state.session = { title, queue, total: queue.length, doneNote, grades: { again: 0, hard: 0, good: 0, easy: 0 } };
  push({ name: 'session' });
}

SCREENS.session = () => runScreen(state.session, cardStep, (session) => {
  const { again, hard, good, easy } = session.grades;
  return runDone('Готово на сегодня', [
    `${plural(session.total, CARD_FORMS)}: легко ${easy}, хорошо ${good}, трудно ${hard}, снова ${again}`,
    `${session.doneNote} Следующее повторение завтра.`.trim(),
  ]);
});

function cardStep(session, next) {
  const word = session.queue[0];
  const plain = plainOf(word.fr);
  const tag = () => h('span', { class: 'flash-tag', text: word.lesson > 0 ? `Урок ${word.lesson}` : 'Из читалки' });
  const card = h('button', { class: 'flashcard', 'aria-label': `${plain}. Показать ответ`, onclick: flip },
    h('span', { class: 'flash-inner' },
      h('span', { class: 'face' },
        tag(),
        h('span', { class: 'flash-word', lang: 'fr', text: plain }),
        h('span', { class: 'flash-hint', text: 'Вспомните перевод и произношение' })),
      h('span', { class: 'face face-back' },
        tag(),
        h('span', { class: 'flash-word', lang: 'fr' }, marked(word.fr)),
        ipa(word.ipa),
        h('span', { class: 'flash-ru', text: word.ru }))));
  const actions = h('div', { class: 'session-actions' }, h('button', { class: 'btn-primary', onclick: flip }, 'Показать ответ'));

  const grade = (choice) => {
    session.grades[choice.id] += 1;
    session.queue.shift();
    if (choice.next === null) session.queue.push(word); // "Снова" returns the card to the end of the queue
    else word.status = choice.next;
    next();
  };
  function flip() {
    if (card.classList.contains('is-flipped')) return;
    card.classList.add('is-flipped');
    card.setAttribute('aria-label', `${plain}: ${word.ru}`);
    actions.replaceChildren(...GRADES.map((choice) =>
      h('button', { class: 'grade', 'data-g': choice.id, onclick: () => grade(choice) }, choice.label, h('small', { text: choice.wait }))));
  }
  return [h('div', { class: 'flash-wrap' }, card, speakButton(plain, 'flash-audio')), actions];
}
