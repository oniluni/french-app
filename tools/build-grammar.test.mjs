import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { build, serialize } from './build-grammar.mjs';
import { workshops } from './grammar.mjs';

test('grammar: every workshop has theory and a test', () => {
  const content = build();
  assert.equal(content.version, 1);
  assert.equal(content.workshops.length, 8);
  assert.equal(new Set(content.workshops.map((workshop) => workshop.id)).size, 8);
  for (const workshop of content.workshops) {
    assert.ok(workshop.title.length > 0);
    assert.ok(workshop.subtitle.length > 0);
    assert.ok(workshop.icon.length > 0);
    assert.ok(workshop.level.length > 0);
    assert.ok(workshop.blocks.length > 0);
    assert.ok(workshop.questions.length >= 4, `${workshop.id}: too few questions`);
    for (const question of workshop.questions) {
      assert.ok(question.options.length >= 3);
      assert.ok(Number.isInteger(question.answer));
      assert.ok(question.answer >= 0 && question.answer < question.options.length);
      assert.ok(question.explanation.length > 0);
    }
  }
});

test('grammar: the right answer is not always the first option', () => {
  const answers = build().workshops.flatMap((workshop) => workshop.questions.map((question) => question.answer));
  assert.ok(new Set(answers).size >= 3, `answers sit in only ${new Set(answers).size} positions`);
  assert.ok(answers.filter((answer) => answer === 0).length < answers.length / 2, 'the first row is the answer too often');
});

test('grammar: the bundled file is current', () => {
  const bundled = JSON.parse(readFileSync(new URL('../App/Resources/grammar.json', import.meta.url), 'utf8'));
  assert.deepEqual(bundled, build());
});

test('grammar: an incomplete question is rejected', () => {
  const source = structuredClone(workshops[0]);
  source.questions[0].answer = 9;
  assert.throws(() => serialize(source), /answer is not an option index/);
});

test('grammar: duplicate options are rejected', () => {
  const source = structuredClone(workshops[0]);
  source.questions[0].options[1] = source.questions[0].options[0];
  assert.throws(() => serialize(source), /options repeat/);
});

test('grammar: an empty theory is rejected', () => {
  const source = structuredClone(workshops[0]);
  source.theory = '   ';
  assert.throws(() => serialize(source), /no theory/);
});
