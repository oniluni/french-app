// Aligns French spelling with its IPA and derives the pronunciation markup:
//   (x) silent letters   [x] nasal vowel   {x} consonant heard only in a liaison   ‿ liaison
//
// The IPA is given (lesson files, Lexique), so nothing is guessed about how a word sounds.
// The only question answered here is which letters produce which sounds.

/** Letters → the sound strings they can stand for. "" is silent, a leading "?" marks a rare reading. */
const GRAPHEMES = {
  a: 'a ɑ  ?o ?ɔ ?ɛ', à: 'a ɑ', â: 'ɑ a', æ: 'e', ea: '?i',
  e: 'ə ɛ e  ?a ?œ ?ø', é: 'e ɛ', è: 'ɛ e', ê: 'ɛ e', ë: 'ɛ e ',
  i: 'i j ij ', î: 'i', ï: 'i j', y: 'i j ij', ÿ: 'i',
  o: 'ɔ o ', ô: 'o ɔ', œ: 'œ ø e ɛ',
  u: 'y ɥ  ?ɔ ?œ', û: 'y', ù: 'y', ü: 'y',
  ai: 'ɛ e ?ə', aî: 'ɛ e', ei: 'ɛ e', ay: 'ɛj ej ei ɛ e', ey: 'ɛ ɛj e',
  au: 'o ɔ', eau: 'o', eu: 'ø œ ?y', eû: 'ø y', œu: 'œ ø', ue: '?œ',
  ou: 'u w', où: 'u', oû: 'u', oi: 'wa wɑ', oî: 'wa wɑ', oy: 'waj wa', oe: '?wa', oê: 'wa', oo: '?u ?ɔ', ee: '?i',
  aou: '?u', aoû: 'u',
  an: 'ɑ̃', am: 'ɑ̃', en: 'ɑ̃ ɛ̃', em: 'ɑ̃', aon: '?ɑ̃',
  in: 'ɛ̃', im: 'ɛ̃', în: 'ɛ̃', yn: 'ɛ̃', ym: 'ɛ̃', ain: 'ɛ̃', aim: 'ɛ̃', ein: 'ɛ̃',
  un: 'œ̃ ɛ̃ ?ɔ̃', um: 'œ̃ ɛ̃', on: 'ɔ̃ ?ə', om: 'ɔ̃', oin: 'wɛ̃',
  b: 'b  ?p', bb: 'b', c: 'k s  ?ɡ', ç: 's', cc: 'k ks', ch: 'ʃ k', ck: 'k', cqu: 'k',
  d: 'd  t', dd: 'd', f: 'f  ?v', ff: 'f',
  g: 'ɡ ʒ  ?k', gg: 'ɡ ɡʒ', ge: 'ʒ', gu: 'ɡ ɡɥ ɡw', gn: 'ɲ ɡn', ng: '?ŋ',
  h: '', j: 'ʒ ?dʒ', k: 'k', l: 'l ', ll: 'l j', ill: 'ij j', il: 'j',
  m: 'm ', mm: 'm', n: 'n ', nn: 'n', p: 'p ', pp: 'p', ph: 'f',
  q: 'k', qu: 'k kw kɥ', r: 'ʁ ', rr: 'ʁ', s: 's z ', ss: 's', sc: 's sk', sch: 'ʃ', sh: '?ʃ',
  t: 't s ', tt: 't', v: 'v', w: 'w v', x: 'ks ɡz s z  k', z: 'z  s', zz: 'z dz',
};

/** Graphemes that only apply before certain letters. */
const ONLY_BEFORE = {
  ge: /^[aâoôuû]/, // the e keeps g soft: mangeons. Elsewhere e is a letter of its own.
  il: /^$/,        // travail, soleil: only at the end of a word
  ue: /^il/,       // accueil, cueillir
};

const COST_SILENT = 1;
// Breaks ties towards silent letters at the end of a word: (h)abit(ent), not (h)abi(ten)t.
const COST_SILENT_EARLY = 0.001;
const COST_RARE = 2;
const COST_NASAL_LINK = 0.5;
const COST_OPAQUE = 12;
const MAX_OPAQUE_PHONEMES = 14;

const NASAL = /̃/;
const VOWEL_OR_GLIDE = /^[aɑeɛiouyøœəɔjwɥ]/;
/** Final letters that are normally silent and wake up in a liaison. */
const LIAISON_SOUNDS = { s: 'z', x: 'z', z: 'z', t: 't', d: 't', n: 'n', p: 'p', g: 'kɡ' };
const WORD_NASALS = ['ain', 'ein', 'an', 'en', 'in', 'on', 'un'];

// Digits form a word too, one no spelling rule applies to: it is skipped as a block.
const isWordChar = (char) => /[\p{L}\p{Nd}]/u.test(char);

/** "ɑ̃ (ə)‿z" → phonemes with their flags. Brackets, stress and length marks are dropped. */
export function phonemesOf(ipa) {
  const out = [];
  let optional = false;
  for (const char of ipa.normalize('NFD').replaceAll('g', 'ɡ').replaceAll('r', 'ʁ')) {
    if (char === '(') optional = true;
    else if (char === ')') optional = false;
    else if (char === '̃') { if (out.length > 0) out[out.length - 1].p += char; }
    else if (char === '‿') { if (out.length > 0) out[out.length - 1].tieAfter = true; }
    else if (/[\p{Ll}\p{Lu}]/u.test(char)) out.push({ p: char, optional }); // not ː or ˈ
  }
  return out;
}

const RULES = Object.entries(GRAPHEMES).map(([letters, readings]) => ({
  letters,
  readings: readings.split(' ').map((reading) => {
    const rare = reading.startsWith('?');
    const phonemes = phonemesOf(rare ? reading.slice(1) : reading).map((item) => item.p);
    const cost = phonemes.length === 0 ? (letters === 'h' ? 0 : COST_SILENT * letters.length) : rare ? COST_RARE : 0;
    return { phonemes, cost };
  }),
}));

/**
 * @param {string[]} tokens words as written, punctuation allowed: ["Les", "enfants", "habitent."]
 * @param {string} ipa transcription of the whole phrase
 * @param {(word: string, phoneme: string) => boolean | undefined} [endsWith] whether the word said
 *   alone ends in this sound; tells a liaison from a consonant that is always pronounced
 * @returns {null | {marked: string | null, ipa: string, link: string, tie: boolean,
 *   chunks: {letters: string, sounds: string, kind: string, final: boolean}[]}[]} one entry per
 *   token, or null if the letters cannot produce the transcription. `marked` is null for a token
 *   that had to be skipped (digits, abbreviations). `chunks` says which letters gave which sounds;
 *   `final` is set on the last letters of a word and on the silent ones after them.
 */
export function align(tokens, ipa, endsWith = () => undefined) {
  const letters = [];
  let run = -1;
  tokens.forEach((token, t) => {
    let inRun = false;
    [...token.normalize('NFC')].forEach((char, at) => {
      if (!isWordChar(char)) { inRun = false; return; }
      if (!inRun) run += 1;
      inRun = true;
      letters.push({ char, lower: char.toLowerCase(), token: t, run, at });
    });
  });
  const sounds = phonemesOf(ipa);
  const path = bestPath(letters, sounds);
  if (!path) return null;
  return render(tokens, letters, sounds, path, endsWith);
}

/** Cheapest way to spend every letter and every sound. Returns chunks of letters with their sounds. */
function bestPath(letters, sounds) {
  const L = letters.length;
  const S = sounds.length;
  const best = Array.from({ length: L + 1 }, () => new Array(S + 1).fill(Infinity));
  const from = Array.from({ length: L + 1 }, () => new Array(S + 1).fill(null));
  best[0][0] = 0;
  const runEnd = (i) => { let end = i; while (end < L && letters[end].run === letters[i].run) end += 1; return end; };
  const relax = (i, j, toI, toJ, cost, kind) => {
    if (best[i][j] + cost < best[toI][toJ]) {
      best[toI][toJ] = best[i][j] + cost;
      from[toI][toJ] = { i, j, kind };
    }
  };

  for (let i = 0; i < L; i++) {
    const end = runEnd(i);
    const rest = letters.slice(i, end).map((item) => item.lower).join('');
    for (let j = 0; j <= S; j++) {
      if (best[i][j] === Infinity) continue;
      for (const rule of RULES) {
        if (!rest.startsWith(rule.letters)) continue;
        const after = rest.slice(rule.letters.length);
        if (ONLY_BEFORE[rule.letters] && !ONLY_BEFORE[rule.letters].test(after)) continue;
        for (const reading of rule.readings) {
          if (!matches(sounds, j, reading.phonemes)) continue;
          const early = reading.phonemes.length === 0 ? COST_SILENT_EARLY * (end - i) : 0;
          relax(i, j, i + rule.letters.length, j + reading.phonemes.length, reading.cost + early, 'plain');
        }
        // "un ami": the vowel stays nasal and the n is heard as well.
        if (after === '' && WORD_NASALS.includes(rule.letters)) {
          for (const reading of rule.readings) {
            if (reading.phonemes.length === 1 && NASAL.test(reading.phonemes[0]) && matches(sounds, j, [reading.phonemes[0], 'n'])) {
              relax(i, j, i + rule.letters.length, j + 2, COST_NASAL_LINK, 'nasal-link');
            }
          }
        }
      }
      // A run nothing can explain ("M.", "RTL", "7") takes its sounds as a block and stays unmarked.
      if (i === 0 || letters[i - 1].run !== letters[i].run) {
        for (let k = 0; k <= MAX_OPAQUE_PHONEMES && j + k <= S; k++) relax(i, j, end, j + k, COST_OPAQUE + k, 'opaque');
      }
    }
  }
  if (best[L][S] === Infinity) return null;

  const chunks = [];
  for (let i = L, j = S; i > 0 || j > 0;) {
    const step = from[i][j];
    chunks.unshift({ start: step.i, end: i, soundStart: step.j, soundEnd: j, kind: step.kind });
    ({ i, j } = step);
  }
  return chunks;
}

const matches = (sounds, j, phonemes) =>
  j + phonemes.length <= sounds.length && phonemes.every((phoneme, k) => sounds[j + k].p === phoneme);

function render(tokens, letters, sounds, chunks, endsWith) {
  const runs = [];
  for (const chunk of chunks) {
    const first = letters[chunk.start];
    const info = runs[first.run] ??= { token: first.token, chunks: [], opaque: false, link: null };
    info.chunks.push(chunk);
    if (chunk.kind === 'opaque') info.opaque = true;
  }
  const runSounds = (info) => info.chunks.flatMap((chunk) => sounds.slice(chunk.soundStart, chunk.soundEnd));
  const wordOf = (info) => letters.slice(info.chunks[0].start, info.chunks.at(-1).end).map((item) => item.lower).join('');

  // A liaison consonant belongs to the letters of one word and to the sound of the next.
  runs.forEach((info, r) => {
    const next = runs[r + 1];
    if (!next || info.opaque || next.opaque) return;
    if (wordOf(info).length === 1) return; // the t of "a-t-il" is a word of its own, always heard
    const nextSounds = runSounds(next);
    if (nextSounds.length === 0 || !VOWEL_OR_GLIDE.test(nextSounds[0].p)) return;
    const voiced = info.chunks.filter((chunk) => chunk.soundEnd > chunk.soundStart);
    const last = voiced.at(-1);
    if (!last) return;
    const phoneme = sounds[last.soundEnd - 1].p;
    if (last.kind === 'nasal-link') {
      info.link = { chunk: last, phoneme };
      return;
    }
    const letter = letters[last.start].lower;
    if (last.end - last.start !== 1 || last.soundEnd - last.soundStart !== 1 || !LIAISON_SOUNDS[letter]?.includes(phoneme)) return;
    // Only the word's own final letters may follow: "ils" yes, "Denise" no (its s is always heard).
    const tail = letters.slice(last.end, info.chunks.at(-1).end).map((item) => item.lower).join('');
    if (!/^[sxtdp]*$/.test(tail)) return;
    const always = endsWith(wordOf(info), phoneme);
    if (always === true) return;
    if (always === undefined && letter === 'n') return;
    info.link = { chunk: last, phoneme };
  });

  return tokens.map((token, t) => {
    const mine = runs.map((info, r) => ({ info, r })).filter(({ info }) => info.token === t);
    if (mine.length === 0) return { marked: token, ipa: '', link: '', tie: false, chunks: [] };
    const chars = [...token.normalize('NFC')];
    const kindAt = new Array(chars.length).fill('none');
    const described = [];
    let ipa = '';
    for (const { info, r } of mine) {
      const previous = runs[r - 1];
      if (previous?.link && previous.token === t) ipa += previous.link.phoneme;
      const lastVoiced = info.chunks.findLast((chunk) => chunk.soundEnd > chunk.soundStart);
      for (const chunk of info.chunks) {
        const chunkSounds = sounds.slice(chunk.soundStart, chunk.soundEnd);
        const isLink = info.link?.chunk === chunk;
        const spoken = isLink ? chunkSounds.slice(0, -1) : chunkSounds;
        ipa += spoken.map((sound) => (sound.optional ? `(${sound.p})` : sound.p)).join('');
        const span = letters.slice(chunk.start, chunk.end);
        span.forEach((item, k) => {
          let kind = 'plain';
          if (chunkSounds.length === 0) kind = 'silent';
          else if (chunk.kind === 'nasal-link') kind = k === span.length - 1 ? 'link' : 'nasal';
          else if (isLink) kind = 'link';
          else if (chunkSounds.some((sound) => NASAL.test(sound.p))) kind = 'nasal';
          kindAt[item.at] = kind;
        });
        described.push({
          letters: span.map((item) => item.lower).join(''),
          sounds: chunkSounds.map((sound) => sound.p).join(''),
          kind: kindAt[span[0].at],
          final: !lastVoiced || chunk.start >= lastVoiced.start,
        });
      }
    }
    const first = mine[0];
    const before = runs[first.r - 1];
    const lastSoundBefore = before ? runSounds(before).at(-1) : null;
    const link = before?.link && before.token !== t ? before.link.phoneme : '';
    return {
      marked: mine.some(({ info }) => info.opaque) ? null : markUp(chars, kindAt),
      ipa: ipa.normalize('NFC'),
      link,
      tie: link !== '' || Boolean(lastSoundBefore?.tieAfter) || tiedInside(before, sounds),
      chunks: described,
    };
  });
}

/** "le‿zimaʒ": the tie is written before the liaison consonant, one sound inside the first word. */
function tiedInside(before, sounds) {
  if (!before?.link) return false;
  const index = before.link.chunk.soundEnd - 2;
  return index >= 0 && Boolean(sounds[index].tieAfter);
}

const OPEN = { silent: '(', nasal: '[', link: '{' };
const CLOSE = { silent: ')', nasal: ']', link: '}' };

function markUp(chars, kindAt) {
  let out = '';
  chars.forEach((char, i) => {
    const kind = kindAt[i];
    const same = (j) => j >= 0 && j < chars.length && kindAt[j] === kind;
    if (OPEN[kind] && !same(i - 1)) out += OPEN[kind];
    out += char;
    if (CLOSE[kind] && !same(i + 1)) out += CLOSE[kind];
  });
  return out;
}

/** Marked phrase from aligned tokens, with ‿ where two words are tied: "le{s}‿[en]f[an](ts)". */
export function joinMarked(aligned) {
  return aligned.map((item, i) => (i === 0 ? '' : item.tie ? '‿' : ' ') + item.marked).join('');
}

/** One word or phrase → its marked form, or null when it cannot be aligned. */
export function mark(text, ipa, endsWith) {
  const aligned = align(text.split(/\s+/).filter(Boolean), ipa, endsWith);
  if (!aligned || aligned.some((item) => item.marked === null)) return null;
  return joinMarked(aligned);
}
