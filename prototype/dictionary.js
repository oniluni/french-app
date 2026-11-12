'use strict';
// Dictionary (the search tab): every lesson word, filtered by the search field in the tab bar.

function wordRow(word) {
  return h('button', { class: 'list-row', onclick: () => push({ name: 'word', query: plainOf(word.fr), set: null }) },
    h('span', { class: 'row-main' },
      h('span', { class: 'row-fr', lang: 'fr', text: plainOf(word.fr) }),
      h('span', { class: 'row-sub', text: word.ru })),
    h('span', { class: 'row-side' },
      ipa(word.ipa),
      h('span', { class: `status is-${word.status}`, text: STATUS_LABELS[word.status] })));
}

SCREENS.dict = () => {
  const { query, lesson } = state.dict;
  const needle = query.trim().toLowerCase();
  const found = WORDS.filter((word) =>
    (lesson === null || word.lesson === lesson)
    && (plainOf(word.fr).toLowerCase().includes(needle) || word.ru.toLowerCase().includes(needle)));
  const lessonIds = [...new Set(found.map((word) => word.lesson))].sort((a, b) => a - b);
  const groupTitle = (id) => {
    const item = lessonById(id);
    return item ? `Урок ${item.id} · ${item.fr}` : 'Добавлено из читалки';
  };
  const setLesson = (id) => {
    state.dict.lesson = id;
    show('none');
  };

  const chips = h('div', { class: 'chips', role: 'group', 'aria-label': 'Фильтр по уроку' },
    chip('Все уроки', lesson === null, () => setLesson(null)),
    LESSONS.map((item) => chip(`Урок ${item.id}`, lesson === item.id, () => setLesson(item.id))));
  // The row is rebuilt on every filter change, so bring the chosen chip back into view.
  requestAnimationFrame(() => {
    const chosen = chips.querySelector('[aria-pressed="true"]');
    chips.scrollLeft = chosen.offsetLeft - chips.offsetLeft - (chips.clientWidth - chosen.offsetWidth) / 2;
  });

  return screenShell({ isRoot: true },
    h('h1', { class: 'large-title', text: 'Словарь' }),
    h('p', { class: 'caption', text: 'Нажмите на слово, чтобы открыть разбор: произношение, род, число и формы.' }),
    chips,
    found.length === 0
      ? h('p', { class: 'empty', text: `По запросу «${query.trim()}» ничего не найдено. Проверьте написание или выберите «Все уроки».` })
      : lessonIds.map((id) => [
        h('h2', { class: 'group-title', text: groupTitle(id) }),
        h('div', { class: 'list' }, found.filter((word) => word.lesson === id).map(wordRow)),
      ]));
};
