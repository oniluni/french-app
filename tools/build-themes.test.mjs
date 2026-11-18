import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { bare, buildThemes, isProperName, isStandaloneArticle, readLexicon, serialize } from './build-themes.mjs';
import { THEMES } from './themes.mjs';

const readings = new Map([
  ['famille', 'famill(e)=famij'],
  ['aller', 'alle(r)=ale'],
]);

test('themes: every topic has an id, a title, an icon and translated words', () => {
  const ids = new Set();
  for (const theme of THEMES) {
    assert.ok(theme.id, 'an id');
    assert.ok(theme.title.trim(), `a title for ${theme.id}`);
    assert.ok(theme.icon.trim(), `an icon for ${theme.id}`);
    assert.ok(theme.words.length >= 25, `${theme.title} has enough words`);
    assert.ok(!ids.has(theme.id), `${theme.id} is unique`);
    ids.add(theme.id);
    for (const word of theme.words) assert.ok(word.fr && word.ru, `${theme.id}: ${word.fr || '(empty)'} has a translation`);
  }
});

test('themes: a word takes its sound from the lexicon, the bare form of an article', () => {
  assert.equal(bare('la famille'), 'famille');
  assert.equal(bare("l'école"), 'école');
  const [theme] = buildThemes(
    [{ id: 'test', title: 'Тест', icon: 'star', words: [{ fr: 'la famille', ru: 'семья' }, { fr: 'aller', ru: 'идти' }] }],
    readings,
  );
  assert.equal(theme.words[0].ipa, 'famij');
  assert.equal(theme.words[0].m, undefined);
  assert.equal(theme.words[1].ipa, 'ale');
  assert.equal(theme.words[1].m, 'alle(r)');
});

test('themes: an explicit pronunciation wins, and a duplicate is rejected', () => {
  const [theme] = buildThemes(
    [{ id: 'test', title: 'Тест', icon: 'star', words: [{ fr: "s'arrêter", ru: 'останавливаться', ipa: 'saʁete' }] }],
    readings,
  );
  assert.equal(theme.words[0].ipa, 'saʁete');
  assert.throws(() => serialize([{ id: 'a', title: 'A', icon: 'star', words: [{ fr: 'aller', ru: 'идти' }, { fr: 'aller', ru: 'ехать' }] }], readings), /listed twice/);
  assert.throws(() => serialize([{ id: 'a', title: 'A', icon: 'star', words: [] }, { id: 'a', title: 'B', icon: 'star', words: [] }], readings), /listed twice/);
});

test('themes: a standalone article or a proper name is rejected', () => {
  assert.equal(isStandaloneArticle('le'), true);
  assert.equal(isStandaloneArticle('l’'), true);
  assert.equal(isStandaloneArticle('la ville'), false);
  assert.equal(isProperName('Paris'), true);
  assert.equal(isProperName('Marie'), true);
  assert.equal(isProperName('la ville'), false);
  assert.throws(
    () => serialize([{ id: 'a', title: 'A', icon: 'star', words: [{ fr: 'le', ru: 'артикль' }] }], readings),
    /article, not a word/,
  );
  assert.throws(
    () => serialize([{ id: 'a', title: 'A', icon: 'star', words: [{ fr: 'Paris', ru: 'Париж' }] }], readings),
    /proper name/,
  );
});

test('themes: the generated file has the topics and a sound for every word', () => {
  const file = JSON.parse(readFileSync(new URL('../App/Resources/themes.json', import.meta.url), 'utf8'));
  assert.equal(file.version, 1);
  assert.deepEqual(file.themes.map((theme) => theme.id), THEMES.map((theme) => theme.id));
  for (const theme of file.themes) {
    for (const word of theme.words) {
      assert.ok(word.fr && word.ru, `${theme.id}: ${word.fr} is translated`);
      assert.ok(word.ipa, `${theme.id}: ${word.fr} has a pronunciation`);
      assert.equal(word.pos, '');
    }
  }
});

test('themes: the lexicon reader keeps the first reading of a spelling', () => {
  const found = readLexicon('aller\talle(r)=ale|aller=ale\taller;VER;;;;inf\nfamille\tfamill(e)=famij\tfamille;NOM;f;s;;0\n');
  assert.equal(found.get('aller'), 'alle(r)=ale');
  assert.equal(found.get('famille'), 'famill(e)=famij');
});
