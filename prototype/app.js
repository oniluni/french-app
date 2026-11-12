'use strict';
// Prototype shell: DOM helpers, app state, navigation, overlays, boot.
// Load order: data.js, app.js, pronunciation.js, then the feature files that fill SCREENS.

const SVG_NS = 'http://www.w3.org/2000/svg';
const WORD_FORMS = ['слово', 'слова', 'слов'];

/** Screen builders by view name. Each takes its view object and returns a .screen element. */
const SCREENS = {};

const state = {
  tab: 'lessons',
  lastTab: 'lessons', // stays visible as the collapsed tab while the dictionary search is open
  stacks: {
    lessons: [{ name: 'lessons' }],
    practice: [{ name: 'practice' }],
    tools: [{ name: 'tools' }],
    dict: [{ name: 'dict' }],
  },
  isPhonetic: false,
  notes: structuredClone(SEED_NOTES),
  sets: [{ from: 1, to: 4 }],
  range: { from: null, to: null },
  practice: { seg: 'words', tense: null },
  tools: { seg: 'reader', text: null, sample: 0, word: { query: 'buvons', set: null } },
  dict: { query: '', lesson: null },
  session: null,
  drill: null,
};

// --- DOM helpers ---

function must(selector) {
  const node = document.querySelector(selector);
  if (!node) throw new Error(`Missing element ${selector} in index.html`);
  return node;
}

/** Builds an element. Props: class, text, on<event>, anything else is an attribute. */
function h(tag, props = {}, ...kids) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value === false || value === null || value === undefined) continue;
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? '' : value);
  }
  node.append(...kids.flat(Infinity).filter((kid) => kid !== null && kid !== undefined && kid !== ''));
  return node;
}

function icon(name) {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('class', 'icon');
  svg.setAttribute('aria-hidden', 'true');
  const use = document.createElementNS(SVG_NS, 'use');
  use.setAttribute('href', `#i-${name}`);
  svg.append(use);
  return svg;
}

/** Russian plural form: pluralForm(3, ['слово', 'слова', 'слов']) → "слова". */
function pluralForm(count, forms) {
  const mod10 = count % 10;
  const mod100 = count % 100;
  if (mod10 === 1 && mod100 !== 11) return forms[0];
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return forms[1];
  return forms[2];
}
const plural = (count, forms) => `${count} ${pluralForm(count, forms)}`;

// --- Shared screen parts ---

function screenShell({ title = '', isRoot = false, isFullscreen = false, backIcon = 'back', actions = [], fab = null }, ...content) {
  const nav = h('header', { class: 'navbar' },
    isRoot ? null : h('button', { class: 'gbtn glass', 'aria-label': backIcon === 'close' ? 'Закрыть' : 'Назад', onclick: pop }, icon(backIcon)),
    title ? h('span', { class: 'nav-title', text: title }) : null,
    h('div', { class: 'nav-actions' }, actions));
  const classes = `screen${isRoot ? ' is-root' : ''}${isFullscreen ? ' is-fullscreen' : ''}`;
  return h('section', { class: classes }, nav, h('div', { class: 'scroll' }, content), fab);
}

function segmented(options, current, onPick) {
  return h('div', { class: 'segmented', role: 'group' },
    options.map(([id, label]) => h('button', { 'aria-pressed': String(id === current), onclick: () => onPick(id) }, label)));
}

function chip(label, isOn, onPick) {
  return h('button', { class: 'chip', 'aria-pressed': String(isOn), onclick: onPick }, label);
}

/** Fullscreen run through a queue (cards or drill): counter and progress up top, one step at a time. */
function runScreen(run, stepView, doneView) {
  const counter = h('span', { class: 'nav-count' });
  const bar = h('span', { class: 'bar' });
  const stage = h('div', { class: 'session-stage' });
  const step = () => {
    const done = run.total - run.queue.length;
    counter.textContent = `${done} / ${run.total}`;
    bar.style.setProperty('--p', String((done / run.total) * 100));
    stage.replaceChildren(...(run.queue.length > 0 ? stepView(run, step) : doneView(run)));
  };
  step();
  return screenShell({ title: run.title, isFullscreen: true, backIcon: 'close', actions: [counter] }, bar, stage);
}

function runDone(title, lines) {
  return [
    h('div', { class: 'done' },
      h('span', { class: 'done-mark' }, icon('check')),
      h('h1', { class: 'large-title', text: title }),
      lines.map((line) => h('p', { class: 'caption', text: line }))),
    h('div', { class: 'session-actions' }, h('button', { class: 'btn-primary', onclick: pop }, 'Готово')),
  ];
}

// --- Navigation ---

const currentStack = () => state.stacks[state.tab];

function render({ keepScroll = false } = {}) {
  closePopover();
  const host = must('#screens');
  const scrollTop = keepScroll ? host.querySelector('.scroll')?.scrollTop ?? 0 : 0;
  const view = currentStack().at(-1);
  const screen = SCREENS[view.name](view);
  host.replaceChildren(screen);
  must('#screens .scroll').scrollTop = scrollTop;
  syncTabbar(screen.classList.contains('is-fullscreen'));
}

/** dir picks the transition: "push", "pop", "tab" or "none" for an in-place update. */
function show(dir, options) {
  must('#screens').dataset.dir = dir;
  render(options);
}

function switchTab(tab) {
  if (state.tab !== 'dict') state.lastTab = state.tab;
  state.tab = tab;
}

function go(tab) {
  if (state.tab === tab) state.stacks[tab].length = 1; // tapping the active tab returns to its root
  switchTab(tab);
  show('tab');
}

function push(view) {
  currentStack().push(view);
  show('push');
}

function pop() {
  if (currentStack().length > 1) currentStack().pop();
  show('pop');
}

function jumpTo(tab, ...views) {
  closeSheet();
  switchTab(tab);
  state.stacks[tab] = [state.stacks[tab][0], ...views];
  show('tab');
}

function syncTabbar(isHidden) {
  const bar = must('#tabbar');
  const isSearch = state.tab === 'dict';
  bar.hidden = isHidden;
  bar.classList.toggle('is-search', isSearch);
  for (const tab of bar.querySelectorAll('[data-tab]')) {
    if (tab.dataset.tab === state.tab) tab.setAttribute('aria-current', 'page');
    else tab.removeAttribute('aria-current');
    tab.classList.toggle('is-last', tab.dataset.tab === state.lastTab);
  }
  must('#search-open').hidden = isSearch;
  must('#searchfield').hidden = !isSearch;
}

// --- Overlays ---

let closePopover = () => {};
let closeSheet = () => {};

/** Glass popover placed under the last anchor, or above the first one when there is no room below. */
function openPopover(firstAnchor, lastAnchor, content, onClose) {
  closePopover();
  const app = must('#app');
  const popover = h('div', { class: 'popover glass', role: 'dialog', 'aria-label': 'Транскрипция', tabindex: '-1' }, content);
  app.append(popover);
  const frame = app.getBoundingClientRect();
  const below = lastAnchor.getBoundingClientRect().bottom - frame.top + 8;
  const above = firstAnchor.getBoundingClientRect().top - frame.top - popover.offsetHeight - 8;
  const fitsBelow = below + popover.offsetHeight < frame.height - 100;
  popover.style.top = `${fitsBelow ? below : Math.max(above, 60)}px`;
  popover.focus({ preventScroll: true });

  const listeners = new AbortController();
  const { signal } = listeners;
  document.addEventListener('pointerdown', (event) => { if (!popover.contains(event.target)) closePopover(); }, { signal, capture: true });
  document.addEventListener('keydown', (event) => { if (event.key === 'Escape') closePopover(); }, { signal });
  app.addEventListener('scroll', () => closePopover(), { signal, capture: true });
  closePopover = () => {
    closePopover = () => {};
    listeners.abort();
    popover.remove();
    onClose();
  };
}

function openSheet(label, content) {
  closePopover();
  closeSheet();
  const app = must('#app');
  const backdrop = h('div', { class: 'backdrop', onclick: () => closeSheet() });
  const sheet = h('div', { class: 'sheet glass', role: 'dialog', 'aria-modal': 'true', 'aria-label': label, tabindex: '-1' },
    h('span', { class: 'grabber' }), content);
  app.append(backdrop, sheet);
  sheet.focus({ preventScroll: true });

  const listeners = new AbortController();
  document.addEventListener('keydown', (event) => { if (event.key === 'Escape') closeSheet(); }, { signal: listeners.signal });
  closeSheet = () => {
    closeSheet = () => {};
    listeners.abort();
    backdrop.remove();
    sheet.remove();
  };
}

let toastTimer = 0;
function toast(message) {
  const app = must('#app');
  app.querySelector('.toast')?.remove();
  clearTimeout(toastTimer);
  const node = h('div', { class: 'toast glass', role: 'status', text: message });
  app.append(node);
  toastTimer = setTimeout(() => node.remove(), 2400);
}

// --- Page chrome around the phone ---

function setTheme(theme) {
  if (theme) document.documentElement.dataset.theme = theme;
  else delete document.documentElement.dataset.theme;
  for (const button of must('#theme').children) button.setAttribute('aria-pressed', String(button.dataset.themeSet === theme));
}

// Shortcuts from the side rail straight to the screens worth reviewing.
const JUMPS = {
  lessons: () => jumpTo('lessons'),
  text: () => jumpTo('lessons', { name: 'lesson', id: 7, seg: 'text' }),
  notes: () => { JUMPS.text(); openNotes('text-7', 'Урок 7 · текст'); },
  rule: () => jumpTo('lessons', { name: 'lesson', id: 7, seg: 'rules' }, { name: 'rule', id: 'r7-2' }),
  sets: () => { state.practice.seg = 'words'; jumpTo('practice'); },
  card: () => { JUMPS.sets(); startRange(5, 10); },
  drill: () => { state.practice.seg = 'forms'; jumpTo('practice'); startDrill('Смешанная тренировка', ANALYSIS); },
  reader: () => { state.tools.seg = 'reader'; jumpTo('tools'); },
  word: () => { state.tools.seg = 'word'; jumpTo('tools'); },
  dict: () => jumpTo('dict'),
};

function selfCheck() {
  console.assert(JSON.stringify(parseMarked('enf[an](t)')) === '[{"t":"enf"},{"t":"an","k":"nasal"},{"t":"t","k":"silent"}]', 'parseMarked');
  console.assert(plainOf('le{s}‿[en]f[an](ts)') === 'les enfants', 'plainOf');
  console.assert([1, 3, 5, 11, 22].map((n) => pluralForm(n, WORD_FORMS)).join() === 'слово,слова,слов,слов,слова', 'pluralForm');
  console.assert(findAnalysis('nous buvons')?.entry.lemma === 'boire', 'findAnalysis');
}

function boot() {
  selfCheck();
  must('#tabbar').addEventListener('click', (event) => {
    const tab = event.target.closest('[data-tab]');
    if (tab) go(tab.dataset.tab);
  });
  must('#dict-query').addEventListener('input', (event) => {
    state.dict.query = event.target.value;
    show('none');
  });
  must('#jumps').addEventListener('click', (event) => {
    const button = event.target.closest('[data-jump]');
    if (!button) return;
    location.hash = button.dataset.jump; // keeps the link to this screen shareable
    JUMPS[button.dataset.jump]();
  });
  must('#theme').addEventListener('click', (event) => {
    const button = event.target.closest('[data-theme-set]');
    if (button) setTheme(button.dataset.themeSet);
  });
  setTheme(document.documentElement.dataset.theme ?? '');
  show('none');
  const deepLink = location.hash.slice(1);
  if (Object.hasOwn(JUMPS, deepLink)) JUMPS[deepLink]();
}

document.addEventListener('DOMContentLoaded', boot);
