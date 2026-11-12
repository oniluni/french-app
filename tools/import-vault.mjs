#!/usr/bin/env node
// Lesson vault (Markdown, one folder per lesson) → App/Resources/content.json.
//
//   node tools/import-vault.mjs <vault directory>
//
// A lesson is imported when its «Дашборд.md» has `lesson: N` in the front matter. Folders
// without it (raw OCR) are skipped, and appear in the app once they are brought to that format.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { align, joinMarked, phonemesOf } from './align.mjs';
import { download, endsWithFrom, indexByForm, keyOf, loadRows } from './lexique.mjs';
import { parseBlocks, plainText } from './markdown.mjs';

const OUTPUT = new URL('../App/Resources/content.json', import.meta.url).pathname;
const MIN_ALIGNED = 0.97;

const frontMatter = /^---\n([\s\S]*?)\n---\n?/;
const body = (text) => text.replace(frontMatter, '');
const lessonNumber = (text) => Number(/^lesson:\s*(\d+)\s*$/m.exec(frontMatter.exec(text)?.[1] ?? '')?.[1] ?? NaN);
const unbracket = (ipa) => ipa.replace(/[[\]]/g, '').trim();
const bare = (word) => word.replace(/^[^\p{L}\p{Nd}]+|[^\p{L}\p{Nd}]+$/gu, '');
/** Brackets in the French text itself would be read as pronunciation marks. */
const hasMarkCharacters = (text) => /[()[\]{}‿]/.test(text);
export const plainOf = (marked) => marked.replace(/[()[\]{}]/g, '').replaceAll('‿', ' ');

// ---------------------------------------------------------------------------------------------
// Parsing: Markdown → raw lesson parts. No alignment yet.

/** «Слова.md» → the new vocabulary of the lesson and the remarks under its conjugation tables. */
export function parseVocabulary(markdown) {
  const blocks = parseBlocks(body(markdown));
  const start = blocks.findIndex((block) => block.t === 'h' && /Новая лексика/.test(block.md));
  if (start === -1) throw new Error('no «Новая лексика» heading');
  const end = blocks.findIndex((block, i) => i > start && block.t === 'h');
  const table = blocks.slice(start + 1, end === -1 ? undefined : end).find((block) => block.t === 'table');
  if (!table) throw new Error('no table under «Новая лексика»');
  const words = table.rows.filter((row) => row.length >= 4).map(([fr, pos, ipa, ...ru]) => ({
    fr: fr.replaceAll('`', '').trim(),
    pos: plainText(pos),
    ipa: unbracket(ipa),
    ru: plainText(ru.join(' | ')).replace(/^✎\s*/, ''),
  }));

  const verbNotes = {};
  let lemma = null;
  for (const block of blocks) {
    if (block.t === 'h') lemma = / — /.test(block.md) ? block.md.split(' — ')[0].trim().toLowerCase() : null;
    const note = block.t === 'p' ? /^\*\*Особенности:\*\*\s*([\s\S]+)$/.exec(block.md) : null;
    if (lemma && note) verbNotes[lemma] = note[1];
  }
  return { words, verbNotes };
}

const LABEL = { fr: /^\*\*Français\s*:\*\*\s*/, ipa: /^\*\*IPA:\*\*\s*/, ru: /^\*\*Перевод:\*\*\s*/, note: /^\*\*Пояснение:\*\*\s*/ };
const startsWithLabel = (line) => Object.values(LABEL).some((label) => label.test(line));

/** Labelled lines written without a blank line between them are still separate paragraphs. */
function splitLabelledParagraphs(blocks) {
  return blocks.flatMap((block) => {
    if (block.t !== 'p') return [block];
    const parts = [];
    for (const line of block.md.split('\n')) {
      if (parts.length === 0 || startsWithLabel(line)) parts.push(line);
      else parts[parts.length - 1] += `\n${line}`;
    }
    return parts.map((md) => ({ t: 'p', md }));
  });
}

/**
 * «Тексты.md» → sections. A section item is either `{ sentence }` (French, IPA, translation,
 * explanation) or `{ block }` for everything else: drills, summaries, tables without IPA.
 */
export function parseTexts(markdown) {
  const blocks = splitLabelledParagraphs(parseBlocks(body(markdown)));
  const sections = [];
  const hasIpaNext = (i) => blocks[i]?.t === 'p' && LABEL.ipa.test(blocks[i].md);
  let i = 0;
  while (i < blocks.length) {
    const block = blocks[i];
    i += 1;
    if (block.t === 'h' && block.level <= 2) {
      if (block.level === 2) sections.push({ title: block.md, items: [] });
      continue;
    }
    const section = sections.at(-1);
    if (!section || block.t === 'hr') continue; // before the first section: title, links, notation notes
    const numbered = block.t === 'h' ? /^\d+\.\s+(.+)$/.exec(block.md) : null;
    const labelled = block.t === 'p' ? LABEL.fr.exec(block.md) : null;
    if ((numbered || labelled) && hasIpaNext(i)) {
      const sentence = { fr: plainText(numbered ? numbered[1] : block.md.slice(labelled[0].length)), ipa: '', ru: '', note: [] };
      sentence.ipa = blocks[i++].md.replace(LABEL.ipa, '');
      if (blocks[i]?.t === 'p' && LABEL.ru.test(blocks[i].md)) sentence.ru = plainText(blocks[i++].md.replace(LABEL.ru, ''));
      if (blocks[i]?.t === 'p' && LABEL.note.test(blocks[i].md)) {
        const inline = blocks[i++].md.replace(LABEL.note, '');
        if (inline) sentence.note.push({ t: 'p', md: inline });
        while (i < blocks.length && !['h', 'hr'].includes(blocks[i].t) && !(blocks[i].t === 'p' && startsWithLabel(blocks[i].md))) {
          sentence.note.push(blocks[i++]);
        }
      }
      section.items.push({ sentence });
    } else if (block.t === 'table' && ['Français', 'IPA', 'Перевод'].every((name) => block.head.includes(name))) {
      const column = (name) => block.head.indexOf(name);
      for (const row of block.rows) {
        const speaker = column('Français') > 0 ? plainText(row[0]) : '';
        section.items.push({ sentence: { fr: plainText(row[column('Français')]), ipa: row[column('IPA')], ru: plainText(row[column('Перевод')]), note: [], speaker } });
      }
    } else {
      section.items.push({ block });
    }
  }
  return sections;
}

const RULE_KIND = { 'Произношение': 'Произношение', 'Правила чтения': 'Чтение', 'Речевой поток': 'Чтение', 'Грамматика': 'Грамматика' };

function summaryOf(blocks) {
  const first = blocks.find((block) => block.t === 'p' || block.t === 'list');
  const text = plainText(first?.t === 'list' ? first.items[0].md : first?.md ?? '').split('\n')[0];
  return text.length > 110 ? `${text.slice(0, 107).trimEnd()}…` : text;
}

/** «Правила.md» → rules: one per third-level heading, plus the two closing callouts. */
export function parseRules(markdown, lesson) {
  const rules = [];
  let group = null;
  const open = (kind, title) => rules.push({ kind, title, blocks: [] });
  for (const block of parseBlocks(body(markdown))) {
    if (block.t === 'h' && block.level === 2) {
      group = block.md;
      open(RULE_KIND[group] ?? group, group);
    } else if (block.t === 'h' && block.level === 3 && group) {
      open(RULE_KIND[group] ?? group, block.md.replace(/^\d+\.\s+/, ''));
    } else if (block.t === 'callout' && ['info', 'warning'].includes(block.kind)) {
      rules.push({ kind: 'Примечания', title: block.title, blocks: block.blocks });
    } else if (group && block.t !== 'hr' && !(block.t === 'callout' && block.kind === 'note')) {
      rules.at(-1).blocks.push(block);
    }
  }
  return rules.filter((rule) => rule.blocks.length > 0)
    .map((rule, index) => ({ id: `${lesson}-${index + 1}`, ...rule, summary: summaryOf(rule.blocks) }));
}

// ---------------------------------------------------------------------------------------------
// "Почему так читается": which reading rule explains a word.

const sound = (text) => phonemesOf(text).map((item) => item.p).join('');

/**
 * Kinds of reading rule, most specific first: when several rules explain a word, the lowest rank
 * is linked. The same descriptions are evaluated by the app's reader (FrenchCore/ReadingRules.swift).
 */
const RANK = { 'nasal-link': 0, liaison: 1, nasal: 2, sound: 3, h: 3, 'silent-final': 4, 'heard-final': 5, tie: 6 };

/** The description of the rule one item of a «Правила чтения» list states, or null. */
function patternFor(lead) {
  let found;
  if (/^Связывание после носового/.test(lead)) return { kind: 'nasal-link' };
  if (/^Носовые гласные/.test(lead)) return { kind: 'nasal' };
  if ((found = /^(?:Буквенное сочетание )?(\p{L}{1,3})(?: перед гласными)? (?:в большинстве случаев |обычно )?(?:читается(?: обычно)?(?: как)?|=) \[([^\]]+)\]/u.exec(lead))) {
    return { kind: 'sound', letters: found[1], sound: sound(found[2]) };
  }
  if ((found = /^(\p{L}) (?:[^.:]*? )?(?:на конце|в окончании) [^.:]*?(не читается|читается)/u.exec(lead))) {
    return { kind: found[2] === 'не читается' ? 'silent-final' : 'heard-final', letter: found[1] };
  }
  if (/^Сцепление/.test(lead)) return { kind: 'tie' };
  return null;
}

const linkedByNasal = (token) => Boolean(token.before?.chunks.some((chunk) => chunk.kind === 'link' && chunk.letters === 'n'));

/** Whether a rule applies to an aligned token (`before` is the previous token). */
export function applies(pattern, token) {
  switch (pattern.kind) {
    case 'nasal-link': return linkedByNasal(token);
    case 'liaison': return Boolean(token.link) && !linkedByNasal(token);
    case 'nasal': return token.chunks.some((chunk) => chunk.kind === 'nasal');
    case 'sound':
      return token.chunks.some((chunk, i) => [chunk, { letters: chunk.letters + (token.chunks[i + 1]?.letters ?? ''), sounds: chunk.sounds + (token.chunks[i + 1]?.sounds ?? '') }]
        .some((span) => span.letters === pattern.letters && span.sounds === pattern.sound));
    case 'h': return token.chunks.some((chunk) => chunk.letters === 'h' && chunk.kind === 'silent');
    case 'silent-final': return token.chunks.some((chunk) => chunk.final && chunk.kind === 'silent' && chunk.letters.includes(pattern.letter));
    case 'heard-final': return token.chunks.at(-1)?.letters === pattern.letter && token.chunks.at(-1).sounds !== '';
    case 'tie': return Boolean(token.tie) && !token.link;
    default: throw new Error(`Unknown reading rule kind "${pattern.kind}"`);
  }
}

/** Every reading rule a word can be linked to, in lesson order. */
function readingRulesOf(lessons) {
  const found = [];
  const add = (rule, label, pattern) => found.push({ rule, label, pattern, rank: RANK[pattern.kind] });
  // The item that says a silent final consonant wakes up before a vowel, not the one on vowel linking.
  const explainsLiaison = (item) => /связывание.{0,40}согласный/.test(JSON.stringify(item));
  for (const lesson of lessons) {
    for (const rule of lesson.rules.filter((item) => item.kind === 'Чтение')) {
      if (/^Буква h/.test(rule.title)) add(rule.id, rule.title, { kind: 'h' });
      for (const item of rule.blocks.filter((block) => block.t === 'list').flatMap((block) => block.items)) {
        const lead = plainText(item.md.split('\n')[0]);
        const start = lead.split(':')[0].replace(/\.$/, '');
        const label = start.length <= 60 ? start : plainText(/^\*\*(.+?)\*\*/.exec(item.md)?.[1] ?? start).replace(/[.:]$/, '');
        const pattern = patternFor(lead);
        if (pattern) add(rule.id, label, pattern);
      }
      // Liaison has no item of its own: it is explained next to the first silent final letter.
      if (explainsLiaison(rule.blocks) && !found.some((entry) => entry.pattern.kind === 'liaison')) {
        add(rule.id, 'Связывание', { kind: 'liaison' });
      }
    }
  }
  return found;
}

// ---------------------------------------------------------------------------------------------
// Enrichment: marks, sounds per word, glosses, rule links.

/** "Je lis ce livre ." → words with their punctuation attached, joined by no-break spaces. */
export function tokenize(fr) {
  const tokens = [];
  let opening = '';
  for (const chunk of fr.trim().split(/\s+/u)) {
    if (/[\p{L}\p{Nd}]/u.test(chunk)) {
      tokens.push(opening + chunk);
      opening = '';
    } else if (tokens.length === 0 || /^[—–«(]+$/.test(chunk)) {
      opening += `${chunk} `;
    } else {
      tokens[tokens.length - 1] += ` ${chunk}`;
    }
  }
  if (opening && tokens.length > 0) tokens[tokens.length - 1] += ` ${opening.trim()}`;
  return tokens;
}

/** Stand-ins for "something" and "somebody" in dictionary entries: written, never transcribed. */
const PLACEHOLDER = /^(qch|qn|qqn|qqch)[,.]?$/;

function markPhrase(fr, ipa, endsWith) {
  const words = fr.split(/\s+/).filter(Boolean);
  const aligned = align(words, ipa, endsWith);
  if (!aligned || aligned.some((item, i) => item.marked === null && !PLACEHOLDER.test(words[i]))) return null;
  return joinMarked(aligned.map((item, i) => ({ ...item, marked: item.marked ?? words[i] })));
}

/**
 * Vocabulary entry → marked form. Several forms with a sound each ("petit, petite") align as one
 * phrase; one sound for several forms ("joli, jolie" [ʒɔli]) means they are said alike.
 */
function markEntry(fr, ipa, endsWith) {
  if (hasMarkCharacters(fr)) return null;
  const whole = markPhrase(fr, ipa, endsWith);
  if (whole || /[,/]/.test(ipa)) return whole;
  for (const separator of [' / ', ', ']) {
    const forms = fr.split(separator);
    if (forms.length < 2) continue;
    const marked = forms.map((form) => markPhrase(form, ipa, endsWith));
    if (marked.every(Boolean)) return marked.join(separator);
  }
  return null;
}

/**
 * Translation of a word of a text: the vocabulary entry for the form itself, else for its lemma.
 * A word taught twice ("ce": «это», later «этот») is glossed as of the lesson being read.
 */
function glossFinder(lessons, byKey) {
  // What the vocabulary says about this very form outranks what it says about a related one.
  const exact = new Map();
  const related = new Map();
  const remember = (entries, key, lesson, ru) => {
    if (!key) return;
    if (!entries.has(key)) entries.set(key, []);
    entries.get(key).push({ lesson, ru });
  };
  const lemmasOf = (key) => (byKey.get(key) ?? []).map((row) => keyOf(row.lemma));
  for (const lesson of lessons) {
    for (const word of lesson.words) {
      const parts = word.fr.split(', ');
      // "petit, petite" is one word in two forms; "ça, c'est sûr" is one phrase.
      const forms = parts.every((part) => !part.includes(' ')) ? parts : [word.fr];
      for (const form of forms) {
        const key = keyOf(bare(form));
        const withoutArticle = key.replace(/^(le |la |les |un |une |des |se |l'|s')/, '');
        for (const each of new Set([key, withoutArticle])) remember(exact, each, lesson.id, word.ru);
        for (const lemma of lemmasOf(withoutArticle)) remember(related, lemma, lesson.id, word.ru);
      }
    }
  }
  return (token, lesson) => {
    const key = keyOf(bare(token));
    const afterElision = key.replace(/^.*'/, '');
    const candidates = [key, afterElision, ...lemmasOf(key), ...lemmasOf(afterElision)];
    for (const entries of [exact, related]) {
      for (const candidate of candidates) {
        const known = entries.get(candidate);
        if (known) return (known.findLast((entry) => entry.lesson <= lesson) ?? known[0]).ru;
      }
    }
    return undefined;
  };
}

function enrichSentence(raw, lesson, context, report) {
  const words = tokenize(raw.fr);
  const aligned = hasMarkCharacters(raw.fr) ? null : align(words, raw.ipa, context.endsWith);
  const sentence = { ru: raw.ru };
  if (raw.speaker) sentence.speaker = raw.speaker;
  if (raw.note.length > 0) sentence.note = raw.note;
  report.sentences += 1;
  if (!aligned) {
    report.failedSentences.push(raw.fr);
    sentence.ipa = unbracket(raw.ipa);
    sentence.tokens = words.map((text) => ({ t: text }));
    return sentence;
  }
  if (aligned.every((item) => item.marked !== null)) report.alignedSentences += 1;
  sentence.tokens = aligned.map((item, i) => {
    const token = item.marked === null ? { t: words[i] } : { m: item.marked };
    if (item.marked === null) report.skippedTokens.push(`${words[i]} (${raw.fr})`);
    if (item.ipa) token.ipa = item.ipa;
    if (item.link) token.link = item.link;
    if (item.tie) token.tie = true;
    const gloss = context.gloss(words[i], lesson);
    if (gloss) token.g = gloss;
    const subject = { ...item, before: aligned[i - 1] };
    const rule = item.marked === null ? -1 : context.readingRules
      .map((entry, index) => ({ ...entry, index }))
      .filter((entry) => applies(entry.pattern, subject))
      .sort((a, b) => a.rank - b.rank)[0]?.index ?? -1;
    if (rule >= 0) token.r = rule;
    return token;
  });
  return sentence;
}

// ---------------------------------------------------------------------------------------------

function readLesson(directory) {
  const read = (name) => {
    const path = join(directory, `${name}.md`);
    return existsSync(path) ? readFileSync(path, 'utf8') : '';
  };
  const dashboard = read('Дашборд');
  const id = lessonNumber(dashboard);
  if (Number.isNaN(id)) return null;
  const stage = (name, parse) => {
    try {
      return parse(read(name));
    } catch (error) {
      throw new Error(`${directory}/${name}.md: ${error.message}`, { cause: error });
    }
  };
  const topic = /^#\s+Урок\s+\d+\.\s*(.+)$/m.exec(dashboard)?.[1].trim() ?? '';
  return { id, topic, ...stage('Слова', parseVocabulary), sections: stage('Тексты', parseTexts), rules: stage('Правила', (text) => parseRules(text, id)) };
}

export function importVault(vault, lexiqueRows) {
  const lessons = readdirSync(vault, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^Урок \d+$/.test(entry.name))
    .map((entry) => readLesson(join(vault, entry.name)))
    .filter(Boolean)
    .sort((a, b) => a.id - b.id);
  if (lessons.length === 0) throw new Error(`No lesson with "lesson: N" front matter found in ${vault}`);

  const byKey = indexByForm(lexiqueRows);
  const fromLexique = endsWithFrom(byKey);
  // The vocabulary knows the names Lexique does not: "Denise" ends in [z] on its own.
  const said = new Map(lessons.flatMap((lesson) => lesson.words).map((word) => [keyOf(word.fr), word.ipa.normalize('NFD')]));
  const endsWith = (word, phoneme) => (said.has(keyOf(word)) ? said.get(keyOf(word)).endsWith(phoneme) : fromLexique(word, phoneme));

  const readingRules = readingRulesOf(lessons);
  const context = { endsWith, gloss: glossFinder(lessons, byKey), readingRules };
  const report = { words: 0, alignedWords: 0, singleWords: 0, alignedSingleWords: 0, failedWords: [], sentences: 0, alignedSentences: 0, failedSentences: [], skippedTokens: [], duplicates: 0 };
  const taught = new Map(); // French entry → translations already given by earlier lessons
  const verbNotes = {};

  const content = lessons.map((lesson) => {
    Object.assign(verbNotes, lesson.verbNotes);
    const words = [];
    for (const word of lesson.words) {
      // The same entry with the same translation is a repeat. With a new translation it is a new
      // meaning and gets a card of its own, or joins the card of this lesson.
      const before = taught.get(word.fr) ?? [];
      taught.set(word.fr, [...before, word.ru]);
      if (before.includes(word.ru)) { report.duplicates += 1; continue; }
      const sameLesson = words.find((other) => other.fr === word.fr);
      if (sameLesson) { sameLesson.ru += `; ${word.ru}`; continue; }
      const marked = markEntry(word.fr, word.ipa, endsWith);
      const isSingle = !/[\s,/(]/.test(word.fr);
      report.words += 1;
      report.singleWords += isSingle ? 1 : 0;
      if (marked) {
        report.alignedWords += 1;
        report.alignedSingleWords += isSingle ? 1 : 0;
      } else {
        report.failedWords.push(`${word.fr} [${word.ipa}]`);
      }
      words.push(marked ? { ...word, m: marked } : word);
    }
    const sections = lesson.sections.map((section) => ({
      title: section.title,
      items: section.items.map((item) => (item.sentence ? { sentence: enrichSentence(item.sentence, lesson.id, context, report) } : item)),
    }));
    return { id: lesson.id, topic: lesson.topic, words, sections, rules: lesson.rules };
  });

  return {
    content: { version: 1, lessons: content, readingRules: readingRules.map(({ rule, label, pattern }) => ({ rule, label, pattern })), verbNotes },
    report,
  };
}

/** Every marked string must spell exactly the text it came from. */
function validate(content) {
  const check = (marked, where) => {
    let depth = 0;
    for (const char of marked) {
      if ('([{'.includes(char)) depth += 1;
      if (')]}'.includes(char)) depth -= 1;
      if (depth < 0 || depth > 1) throw new Error(`Broken pronunciation markup "${marked}" in ${where}`);
    }
    if (depth !== 0) throw new Error(`Unclosed pronunciation markup "${marked}" in ${where}`);
  };
  for (const lesson of content.lessons) {
    for (const word of lesson.words) {
      if (!word.m) continue;
      check(word.m, `lesson ${lesson.id} vocabulary`);
      if (plainOf(word.m) !== word.fr) throw new Error(`Marked "${word.m}" does not spell "${word.fr}" (lesson ${lesson.id})`);
    }
    for (const section of lesson.sections) {
      for (const { sentence } of section.items) {
        for (const token of sentence?.tokens ?? []) if (token.m) check(token.m, `lesson ${lesson.id}, ${section.title}`);
      }
    }
  }
}

async function main() {
  const vault = process.argv[2];
  if (!vault) {
    console.error('Usage: node tools/import-vault.mjs <vault directory>');
    process.exit(2);
  }
  await download();
  const { content, report } = importVault(vault, loadRows());
  validate(content);
  writeFileSync(OUTPUT, `${JSON.stringify(content)}\n`);

  const share = (part, whole) => `${part}/${whole} (${(100 * part / whole).toFixed(1)}%)`;
  for (const lesson of content.lessons) {
    const sentences = lesson.sections.flatMap((section) => section.items).filter((item) => item.sentence).length;
    console.log(`Урок ${String(lesson.id).padStart(2)}: ${lesson.words.length} слов, ${sentences} фраз, ${lesson.rules.length} правил`);
  }
  console.log(`\nEntries marked: ${share(report.alignedWords, report.words)}, single words ${share(report.alignedSingleWords, report.singleWords)}; repeated entries skipped: ${report.duplicates}`);
  console.log(`Sentences fully marked: ${share(report.alignedSentences, report.sentences)}`);
  console.log(`Reading rules that words link to: ${content.readingRules.length}`);
  if (report.failedWords.length > 0) console.log(`\nWords left unmarked:\n  ${report.failedWords.join('\n  ')}`);
  if (report.failedSentences.length > 0) console.log(`\nSentences left unmarked:\n  ${report.failedSentences.join('\n  ')}`);
  if (report.skippedTokens.length > 0) console.log(`\nWords skipped inside a sentence:\n  ${report.skippedTokens.join('\n  ')}`);
  console.log(`\nWrote ${OUTPUT}`);

  if (report.alignedSentences / report.sentences < MIN_ALIGNED || report.alignedSingleWords / report.singleWords < MIN_ALIGNED) {
    console.error(`Fewer than ${MIN_ALIGNED * 100}% of the sentences or single words could be marked. Check the transcriptions listed above.`);
    process.exit(1);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
