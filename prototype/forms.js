'use strict';
// Word forms: lookup of any inflected form, the "Разбор слова" view and the form drills.

const DRILL_SIZE = 8;
const QUESTION_FORMS = ['вопрос', 'вопроса', 'вопросов'];

function parseForm(raw) {
  const [written, ipaText] = raw.split('|');
  const [lead, body] = written.split('+');
  return { lead, body, full: lead + body, ipa: ipaText };
}

/** The word itself without a pronoun or article: "nous buvons" → "buvons", "l'enfant" → "enfant". */
const lastWord = (text) => text.trim().toLowerCase().split(/[\s'’]+/).at(-1);

/** Finds the paradigm a typed or tapped form belongs to: "buvons" → { boire, set: Présent }. */
function findAnalysis(text) {
  const key = lastWord(text);
  for (const entry of ANALYSIS) {
    if (entry.lemma === key) return { entry, set: 0, key };
    const set = entry.sets.findIndex((item) => item.forms.some((raw) => plainOf(parseForm(raw).body) === key));
    if (set !== -1) return { entry, set, key };
  }
  return null;
}

/**
 * The analysis of one word. `holder` keeps what is being shown: { query, set }, where `set` is the
 * chosen tense index or null for the one the query was found in.
 */
function wordAnalysis(holder) {
  const hit = findAnalysis(holder.query);
  const word = findWord(hit ? hit.entry.lemma : holder.query);
  const analysed = ANALYSIS.map((entry) => entry.lemma).join(', ');
  if (!hit && !word) {
    return [h('p', { class: 'notice', text: `Слова «${holder.query.trim()}» нет в прототипе. Полный разбор есть для: ${analysed}.` })];
  }

  const lesson = word ? lessonById(word.lesson) : null;
  const title = word ? word.fr : hit.entry.lemma;
  const silent = lettersOf(title, 'silent');
  const nasal = lettersOf(title, 'nasal');
  const facts = [
    ...(hit ? hit.entry.facts : []),
    silent.length > 0 ? ['Не читается', silent.join(', ')] : null,
    nasal.length > 0 ? ['Носовой звук', nasal.join(', ')] : null,
    lesson ? ['Урок', `${lesson.id} · ${lesson.fr}`] : null,
    word ? ['Карточка', STATUS_LABELS[word.status]] : null,
  ].filter(Boolean);

  return [
    h('div', { class: 'card' },
      h('div', { class: 'word-head' },
        h('div', { class: 'row-main' },
          h('span', { class: 'word-fr', lang: 'fr' }, marked(title)),
          word ? ipa(word.ipa) : null),
        speakButton(plainOf(title))),
      word ? h('p', { class: 'word-ru', text: word.ru }) : null,
      h('dl', { class: 'facts' }, facts.map(([label, value]) => [h('dt', { text: label }), h('dd', { text: value })]))),
    hit ? paradigm(hit, holder) : h('p', { class: 'notice', text: `Для этого слова в прототипе нет таблицы форм. Она есть у слов: ${analysed}.` }),
    hit ? h('button', { class: 'btn-primary', onclick: () => startDrill(hit.entry.lemma, [hit.entry]) }, 'Тренировать формы') : null,
    lesson ? h('button', { class: 'btn-quiet', onclick: () => jumpTo('lessons', { name: 'lesson', id: lesson.id, seg: 'words' }) }, `Открыть урок ${lesson.id}`) : null,
  ];
}

/** Forms of the chosen set: a table for six persons, a 2×2 grid for gender and number. */
function paradigm(hit, holder) {
  const { entry, key } = hit;
  const setIndex = holder.set ?? hit.set;
  const set = entry.sets[setIndex];
  const labels = CELL_LABELS[entry.kind];
  const forms = set.forms.map(parseForm);
  const pickSet = (index) => {
    holder.set = index;
    show('none', { keepScroll: true });
  };
  return [
    entry.sets.length > 1 ? segmented(entry.sets.map((item, index) => [index, item.name]), setIndex, pickSet) : h('h2', { class: 'section', text: set.name }),
    h('div', { class: forms.length === 4 ? 'forms is-grid' : 'forms' }, forms.map((form, index) => {
      const plain = plainOf(form.full);
      const isHit = plainOf(form.body) === key;
      return h('button', { class: `form${isHit ? ' is-hit' : ''}`, 'aria-label': `${labels[index]}: ${plain}. Прослушать`, onclick: () => speak(plain) },
        h('span', { class: 'form-label', text: labels[index] }),
        h('span', { class: 'form-fr', lang: 'fr' }, marked(form.full)),
        ipa(form.ipa));
    })),
    h('p', { class: 'caption', text: set.note }),
  ];
}

SCREENS.word = (view) => screenShell({ title: 'Разбор слова' }, wordAnalysis(view));

// --- Drills ---

function shuffle(items) {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/**
 * One question per form of the given entries; setName narrows verbs to a single tense.
 * A form identical to the word shown in the prompt (an adjective's masculine singular) is skipped.
 */
function startDrill(title, entries, setName = null) {
  const questions = entries.flatMap((entry) => entry.sets
    .filter((set) => setName === null || set.name === setName)
    .flatMap((set) => set.forms.map((raw, index) => ({ entry, set, index })))
    .filter(({ entry: owner, set, index }) => plainOf(parseForm(set.forms[index]).full) !== owner.lemma));
  const queue = shuffle(questions).slice(0, DRILL_SIZE);
  state.drill = { title, queue, total: queue.length, right: 0 };
  push({ name: 'drill' });
}

SCREENS.drill = () => runScreen(state.drill, drillStep, (drill) => runDone(`${drill.right} из ${drill.total}`, [
  drill.right === drill.total ? 'Все формы названы верно.' : `Ошибок: ${drill.total - drill.right}. Эти формы стоит повторить ещё раз.`,
]));

function drillStep(drill, next) {
  const { entry, set, index } = drill.queue[0];
  const isVerb = entry.kind === 'verb';
  const forms = set.forms.map(parseForm);
  const asked = forms[index];
  // A verb answer is the form without its pronoun, otherwise the pronoun would give it away.
  const answerOf = (form) => plainOf(isVerb ? form.body : form.full);
  const answer = answerOf(asked);
  const distractors = shuffle([...new Set(forms.map(answerOf))].filter((text) => text !== answer)).slice(0, 3);
  const options = shuffle([answer, ...distractors]);

  const feedback = h('div', { class: 'drill-feedback', 'aria-live': 'polite' });
  const actions = h('div', { class: 'session-actions' });
  const buttons = options.map((text) => h('button', { class: 'option', lang: 'fr', onclick: () => pick(text) }, text));
  function pick(choice) {
    const isRight = choice === answer;
    if (isRight) drill.right += 1;
    buttons.forEach((button, i) => {
      button.disabled = true;
      if (options[i] === answer) button.classList.add('is-right');
      else if (options[i] === choice) button.classList.add('is-wrong');
    });
    feedback.replaceChildren(
      h('span', { class: `verdict${isRight ? ' is-right' : ''}`, text: isRight ? 'Верно' : 'Правильный ответ' }),
      h('span', { class: 'form-fr', lang: 'fr' }, marked(asked.full)),
      ipa(asked.ipa));
    actions.replaceChildren(h('button', { class: 'btn-primary', onclick: () => { drill.queue.shift(); next(); } }, 'Дальше'));
  }

  return [
    h('div', { class: 'drill-card' },
      h('span', { class: 'tag', text: `${entry.lemma} · ${set.name}` }),
      isVerb
        ? h('p', { class: 'drill-prompt', lang: 'fr' }, marked(asked.lead), h('span', { class: 'blank', role: 'img', 'aria-label': 'пропуск' }))
        : h('p', { class: 'drill-prompt', lang: 'fr', text: entry.lemma }),
      h('p', { class: 'drill-ask', text: isVerb ? `Форма для «${CELL_LABELS.verb[index]}»` : CELL_LABELS[entry.kind][index] }),
      feedback),
    h('div', { class: 'drill-options' }, buttons),
    actions,
  ];
}
