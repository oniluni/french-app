import assert from 'node:assert/strict';
import test from 'node:test';
import { serialize } from './build-nuances.mjs';
import { NUANCES } from './nuances.mjs';

test('every note has a lemma, a gloss and an explanation', () => {
  for (const note of NUANCES) {
    assert.ok(note.fr.trim(), 'a French lemma');
    assert.ok(note.title.trim(), `a title for ${note.fr}`);
    assert.ok(note.text.trim(), `an explanation for ${note.fr}`);
  }
});

test('the generated file is sorted and keeps one note per lemma', () => {
  const file = JSON.parse(serialize(NUANCES));
  assert.equal(file.notes.length, NUANCES.length);
  const lemmas = file.notes.map((note) => note.fr);
  assert.deepEqual(lemmas, [...lemmas].sort((a, b) => a.localeCompare(b, 'fr')));
  assert.equal(new Set(lemmas).size, lemmas.length);
});

test('a duplicate lemma is rejected', () => {
  assert.throws(
    () => serialize([{ fr: 'aller', title: 'a', text: 'b' }, { fr: 'aller', title: 'c', text: 'd' }]),
    /listed twice/,
  );
});
