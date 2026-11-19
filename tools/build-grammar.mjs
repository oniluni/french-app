#!/usr/bin/env node
// Grammar workshops (Markdown theory + test questions) → App/Resources/grammar.json.
//
//   node tools/build-grammar.mjs
//
// The theory uses the same Markdown subset as the lesson vault, so it goes through the same
// parser as the rules and renders with the existing BlocksView.
import { writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { parseBlocks } from './markdown.mjs';
import { workshops } from './grammar.mjs';

const OUTPUT = new URL('../App/Resources/grammar.json', import.meta.url).pathname;

const text = (value) => typeof value === 'string' ? value.trim() : '';

/**
 * Keeps the source readable — the right answer is written first — but gives every question its
 * own stable order. A learner must not be able to pass the test by always picking the first row.
 */
function arrange(options, answer, seedText) {
  const order = options.map((_, index) => index);
  let state = 2166136261;
  for (const character of seedText) {
    state ^= character.codePointAt(0);
    state = Math.imul(state, 16777619);
  }
  // Mulberry32: a tiny deterministic generator; the same source always gives the same test.
  const random = () => {
    state = (state + 0x6D2B79F5) | 0;
    let mixed = Math.imul(state ^ (state >>> 15), 1 | state);
    mixed = (mixed + Math.imul(mixed ^ (mixed >>> 7), 61 | mixed)) ^ mixed;
    return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296;
  };
  for (let index = order.length - 1; index > 0; index -= 1) {
    const swap = Math.floor(random() * (index + 1));
    [order[index], order[swap]] = [order[swap], order[index]];
  }
  return { options: order.map((index) => options[index]), answer: order.indexOf(answer) };
}

/** The workshop as the app reads it; throws when the hand-written source is incomplete. */
export function serialize(source) {
  const id = text(source.id);
  if (!id) throw new Error('a workshop has no id');
  const title = text(source.title);
  const subtitle = text(source.subtitle);
  const icon = text(source.icon);
  const level = text(source.level);
  if (!title) throw new Error(`${id}: no title`);
  if (!subtitle) throw new Error(`${id}: no subtitle`);
  if (!icon) throw new Error(`${id}: no icon`);
  if (!level) throw new Error(`${id}: no level`);
  const theory = text(source.theory);
  if (!theory) throw new Error(`${id}: no theory`);
  const blocks = parseBlocks(theory);
  if (blocks.length === 0) throw new Error(`${id}: the theory has no blocks`);

  const questions = (source.questions ?? []).map((question, index) => {
    const where = `${id}, question ${index + 1}`;
    const prompt = text(question.prompt);
    const explanation = text(question.explanation);
    const options = (question.options ?? []).map(text);
    if (!prompt) throw new Error(`${where}: no prompt`);
    if (!explanation) throw new Error(`${where}: no explanation`);
    if (options.length < 3) throw new Error(`${where}: needs at least three options`);
    if (options.some((option) => !option)) throw new Error(`${where}: an option is empty`);
    if (new Set(options).size !== options.length) throw new Error(`${where}: options repeat`);
    if (!Number.isInteger(question.answer) || question.answer < 0 || question.answer >= options.length) {
      throw new Error(`${where}: the answer is not an option index`);
    }
    const arranged = arrange(options, question.answer, `${id}:${index}:${prompt}`);
    return {
      prompt,
      ...(text(question.translation) ? { translation: text(question.translation) } : {}),
      options: arranged.options,
      answer: arranged.answer,
      explanation,
    };
  });
  if (questions.length < 4) throw new Error(`${id}: needs at least four test questions`);

  return { id, title, subtitle, icon, level, blocks, questions };
}

export function build(source = workshops) {
  const seen = new Set();
  const built = source.map(serialize);
  for (const workshop of built) {
    if (seen.has(workshop.id)) throw new Error(`duplicate workshop id: ${workshop.id}`);
    seen.add(workshop.id);
  }
  return { version: 1, workshops: built };
}

function main() {
  const content = build();
  writeFileSync(OUTPUT, `${JSON.stringify(content)}\n`);
  for (const workshop of content.workshops) {
    console.log(`${workshop.id}: ${workshop.blocks.length} theory blocks, ${workshop.questions.length} questions`);
  }
  console.log(`\nWrote ${OUTPUT}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
