#!/usr/bin/env node
// Usage notes for words with several close translations → App/Resources/nuances.json.
//
//   node tools/build-nuances.mjs
//
// The source is hand-written in tools/nuances.mjs. The app reads the file in Core/Nuances.swift;
// it is optional, so an older build without it still starts.
import { statSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { NUANCES } from './nuances.mjs';

const RESOURCES = new URL('../App/Resources/', import.meta.url).pathname;

/** Keep one note per lemma, in alphabetical order, so the file reads and diffs predictably. */
export function serialize(notes) {
  const seen = new Set();
  const sorted = [...notes]
    .map((note) => ({
      fr: note.fr.trim(),
      title: note.title.trim(),
      text: note.text.trim(),
      examples: (note.examples ?? []).map((example) => example.trim()).filter(Boolean),
    }))
    .sort((a, b) => a.fr.localeCompare(b.fr, 'fr'));
  for (const note of sorted) {
    if (!note.fr || !note.title || !note.text) throw new Error(`nuances: an empty note: ${JSON.stringify(note)}`);
    if (seen.has(note.fr)) throw new Error(`nuances: ${note.fr} is listed twice`);
    seen.add(note.fr);
  }
  return `${JSON.stringify({ notes: sorted }, null, 2)}\n`;
}

function main() {
  const path = `${RESOURCES}nuances.json`;
  writeFileSync(path, serialize(NUANCES));
  console.log(`${NUANCES.length} notes`);
  console.log(`nuances.json ${(statSync(path).size / 1e3).toFixed(1)} kB`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
