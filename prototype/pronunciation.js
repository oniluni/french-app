'use strict';
// The pronunciation system shared by lesson texts, cards, rules and the reader:
// markup parsing, annotated text, word and phrase selection, the transcription popover, audio.

const MARKS = { '(': ['silent', ')'], '[': ['nasal', ']'], '{': ['link', '}'] };
const ARTICLE = /^(le |la |les |un |une |l')/;

/** "enf[an](t)" → [{t:'enf'}, {t:'an', k:'nasal'}, {t:'t', k:'silent'}]; "‿" becomes {k:'arc'}. */
function parseMarked(source) {
  const parts = [];
  let plain = '';
  const flush = () => {
    if (plain) parts.push({ t: plain });
    plain = '';
  };
  for (let i = 0; i < source.length; i++) {
    const char = source[i];
    if (char === '‿') {
      flush();
      parts.push({ t: '', k: 'arc' });
      continue;
    }
    const mark = MARKS[char];
    if (!mark) {
      plain += char;
      continue;
    }
    const end = source.indexOf(mark[1], i);
    if (end === -1) throw new Error(`Unclosed "${char}" in pronunciation markup "${source}"`);
    flush();
    parts.push({ t: source.slice(i + 1, end), k: mark[0] });
    i = end;
  }
  flush();
  return parts;
}

const plainOf = (source) => source.replace(/[()[\]{}]/g, '').replaceAll('‿', ' ');
// The liaison arc is drawn under a no-break space, so copied or spoken text still has the word gap.
const arc = () => h('span', { class: 'arc', text: ' ' });
const ipa = (text) => h('span', { class: 'ipa', text });

/** DOM nodes for a marked string: silent, nasal and liaison letters each get their own span. */
function marked(source) {
  return parseMarked(source).map((part) => {
    if (part.k === 'arc') return arc();
    return part.k ? h('span', { class: `m-${part.k}`, text: part.t }) : part.t;
  });
}

/** Letters of one kind in a marked string, e.g. the silent ones: "peti(t) déjeune(r)" → ['t', 'r']. */
const lettersOf = (source, kind) => parseMarked(source).filter((part) => part.k === kind).map((part) => part.t);

function parseToken(raw) {
  if (!raw.includes('|')) return { punct: raw };
  const [src, ipaText, ru, link = '', rule = ''] = raw.split('|');
  return { src, ipa: ipaText, ru, link, rule };
}

/** Flat word list of a text. `s` is the sentence index, `after` the punctuation that follows the word. */
function flattenSentences(sentences) {
  const words = [];
  sentences.forEach((sentence, s) => {
    for (const raw of sentence.tokens) {
      const token = parseToken(raw);
      if (token.punct) words[words.length - 1].after += token.punct;
      else words.push({ ...token, s, after: '' });
    }
  });
  return words;
}

const sentenceText = (sentence) => flattenSentences([sentence]).map((word) => plainOf(word.src) + word.after).join(' ');

/** IPA of words a..b; a liaison consonant is written before its word: "il z‿ɔ̃". */
function phraseIpa(words, a, b) {
  return words.slice(a, b + 1).map((word, i) => (word.link && i > 0 ? `${word.link}‿${word.ipa}` : word.ipa)).join(' ');
}

/** Annotated text. Marks and the IPA line show only while the box has the class "is-phonetic". */
function renderWords(words, notedRanges = []) {
  const box = h('p', { class: 'ftext', lang: 'fr' });
  words.forEach((word, i) => {
    if (i > 0) box.append(word.link ? arc() : ' ');
    const hasNote = notedRanges.some(([a, b]) => i >= a && i <= b);
    box.append(h('span', { class: `tok${hasNote ? ' has-note' : ''}`, 'data-i': String(i), tabindex: '0', role: 'button' },
      h('span', { class: 'tok-w' }, marked(word.src), word.after),
      h('span', { class: 'tok-ipa', text: word.link ? `${word.link}‿${word.ipa}` : word.ipa })));
  });
  return box;
}

/**
 * Tap selects one word; press and drag (mouse) or hold and drag (touch) selects a phrase.
 * Touch needs the hold so that a plain vertical swipe still scrolls the text.
 */
function attachSelection(box, onSelect) {
  const HOLD_MS = 280;
  const SCROLL_SLOP_PX = 8;
  let start = null;
  let end = null;
  let origin = { x: 0, y: 0 };
  let isSelecting = false;
  let holdTimer = 0;

  const indexAt = (x, y) => {
    const token = document.elementFromPoint(x, y)?.closest('.tok');
    return token && box.contains(token) ? Number(token.dataset.i) : null;
  };
  const paint = () => {
    const [a, b] = [Math.min(start, end), Math.max(start, end)];
    for (const token of box.querySelectorAll('.tok')) {
      const i = Number(token.dataset.i);
      token.classList.toggle('is-selected', start !== null && i >= a && i <= b);
    }
  };
  const reset = () => {
    clearTimeout(holdTimer);
    start = null;
    end = null;
    isSelecting = false;
    paint();
  };

  box.addEventListener('pointerdown', (event) => {
    const index = indexAt(event.clientX, event.clientY);
    if (index === null) return;
    start = index;
    end = index;
    origin = { x: event.clientX, y: event.clientY };
    if (event.pointerType === 'mouse') {
      isSelecting = true;
      box.setPointerCapture(event.pointerId);
      paint();
    } else {
      holdTimer = setTimeout(() => {
        isSelecting = true;
        paint();
      }, HOLD_MS);
    }
  });
  box.addEventListener('pointermove', (event) => {
    if (start === null) return;
    if (!isSelecting) {
      if (Math.hypot(event.clientX - origin.x, event.clientY - origin.y) > SCROLL_SLOP_PX) reset();
      return;
    }
    const index = indexAt(event.clientX, event.clientY);
    if (index !== null && index !== end) {
      end = index;
      paint();
    }
  });
  box.addEventListener('pointerup', () => {
    if (start === null) return;
    const [a, b] = [Math.min(start, end), Math.max(start, end)];
    reset();
    onSelect(a, b);
  });
  box.addEventListener('pointercancel', reset);
  box.addEventListener('touchmove', (event) => { if (isSelecting) event.preventDefault(); }, { passive: false });
  box.addEventListener('keydown', (event) => {
    const token = event.target.closest('.tok');
    if (!token || (event.key !== 'Enter' && event.key !== ' ')) return;
    event.preventDefault();
    onSelect(Number(token.dataset.i), Number(token.dataset.i));
  });
}

function speak(text, button = null) {
  if (button) {
    button.classList.add('is-playing');
    setTimeout(() => button.classList.remove('is-playing'), 1200);
  }
  if (!('speechSynthesis' in window)) {
    toast('В этом браузере нет синтеза речи');
    return;
  }
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = 'fr-FR';
  utterance.rate = 0.9;
  utterance.onerror = (event) => {
    if (event.error !== 'interrupted' && event.error !== 'canceled') toast('Не удалось озвучить: нет французского голоса');
  };
  speechSynthesis.cancel();
  speechSynthesis.speak(utterance);
}

function speakButton(text, extraClass = '') {
  return h('button', { class: `gbtn glass ${extraClass}`.trim(), 'aria-label': `Прослушать: ${text}`, onclick: (event) => speak(text, event.currentTarget) }, icon('speaker'));
}

const bareOf = (source) => plainOf(source).toLowerCase().replace(ARTICLE, '');

/** The vocabulary entry for a word, ignoring its article and case. */
const findWord = (text) => WORDS.find((word) => bareOf(word.fr) === bareOf(text)) ?? null;

/** Transcription popover for words a..b of an annotated text. */
function openWordPopover({ box, words, sentences, a, b, lessonId = 0, noteKey = null, noteLabel = '' }) {
  const picked = words.slice(a, b + 1);
  const single = picked.length === 1 ? picked[0] : null;
  const plain = picked.map((word, i) => plainOf(word.src) + (i < picked.length - 1 ? word.after : '')).join(' ');
  const rule = single?.rule ? RULES.find((item) => item.id === single.rule) : null;
  const inVocabulary = single ? findWord(plain) : null;
  const hasForms = single ? findAnalysis(plain) !== null : false;
  const translation = single ? single.ru : [...new Set(picked.map((word) => word.s))].map((s) => sentences[s].ru).join(' ');
  const phrase = picked.map((word, i) => [i > 0 ? (word.link ? arc() : ' ') : null, marked(word.src), i < picked.length - 1 ? word.after : null]);

  const addToCards = () => {
    WORDS.push({ lesson: lessonId, fr: single.src, ipa: single.ipa, ru: single.ru, status: 'new' });
    toast(`«${plain}» добавлено в карточки`);
    closePopover();
  };
  const actions = [
    single && inVocabulary ? h('button', { class: 'chip-btn', disabled: true }, icon('check'), 'В словаре') : null,
    single && !inVocabulary ? h('button', { class: 'chip-btn', onclick: addToCards }, icon('plus'), 'В карточки') : null,
    hasForms ? h('button', { class: 'chip-btn', onclick: () => push({ name: 'word', query: plain, set: null }) }, icon('book'), 'Разбор') : null,
    noteKey ? h('button', { class: 'chip-btn', onclick: () => openNotes(noteKey, noteLabel, { quote: plain, range: [a, b] }) }, icon('note'), 'Заметка') : null,
  ].filter(Boolean);

  const tokens = [...box.querySelectorAll('.tok')];
  const paintSelection = (isOn) => tokens.slice(a, b + 1).forEach((token) => token.classList.toggle('is-selected', isOn));
  paintSelection(true);
  openPopover(tokens[a], tokens[b], [
    h('div', { class: 'pop-head' },
      h('div', { class: 'pop-main' }, h('span', { class: 'pop-word', lang: 'fr' }, phrase), ipa(phraseIpa(words, a, b))),
      speakButton(plain)),
    h('p', { class: 'pop-ru' }, single ? null : h('span', { class: 'pop-label', text: 'Перевод предложения' }), translation),
    rule ? h('button', { class: 'pop-rule', onclick: () => push({ name: 'rule', id: rule.id }) },
      h('span', {}, h('span', { class: 'pop-label', text: 'Почему так читается' }), rule.title), icon('chevron')) : null,
    actions.length > 0 ? h('div', { class: 'pop-actions' }, actions) : null,
  ], () => paintSelection(false));
}
