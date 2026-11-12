// The subset of Markdown the lesson files use → blocks the app can lay out.
// Inline markup (bold, italic, code, strikethrough) stays as Markdown text: the app renders it natively.
//
// Block shapes:
//   { t: 'h', level, md }
//   { t: 'p', md }
//   { t: 'list', ordered, items: [{ md, blocks }] }
//   { t: 'table', head: [md], rows: [[md]] }
//   { t: 'callout', kind, title, blocks }     kind is '' for a plain quote
//   { t: 'hr' }

const HEADING = /^(#{1,6})\s+(.*)$/;
const RULE = /^\s*(-{3,}|\*{3,})\s*$/;
const LIST_ITEM = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/;
const TABLE_SEPARATOR = /^\s*\|?\s*:?-{2,}[\s|:-]*$/;
const CALLOUT = /^\[!(\w+)\][-+]?\s*(.*)$/;

/** Obsidian links and comments have no meaning outside the vault. */
const clean = (text) => text
  .replace(/%%[\s\S]*?%%/g, '')
  .replace(/\[\[([^\]|]*\|)?([^\]]*)\]\]/g, '$2');

export function parseBlocks(source) {
  return parseLines(clean(source).split('\n'));
}

const indentOf = (line) => line.length - line.trimStart().length;
const isTableStart = (lines, i) => lines[i].trimStart().startsWith('|') && i + 1 < lines.length && TABLE_SEPARATOR.test(lines[i + 1]);
const startsBlock = (lines, i) =>
  HEADING.test(lines[i]) || RULE.test(lines[i]) || lines[i].startsWith('>') || LIST_ITEM.test(lines[i]) || isTableStart(lines, i);

function parseLines(lines) {
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const heading = HEADING.exec(line);
    if (line.trim() === '') {
      i += 1;
    } else if (heading) {
      blocks.push({ t: 'h', level: heading[1].length, md: heading[2].trim() });
      i += 1;
    } else if (RULE.test(line)) {
      blocks.push({ t: 'hr' });
      i += 1;
    } else if (line.startsWith('>')) {
      const quoted = [];
      while (i < lines.length && lines[i].startsWith('>')) quoted.push(lines[i++].replace(/^> ?/, ''));
      blocks.push(callout(quoted));
    } else if (isTableStart(lines, i)) {
      const rows = [];
      while (i < lines.length && lines[i].trimStart().startsWith('|')) rows.push(cellsOf(lines[i++]));
      blocks.push({ t: 'table', head: rows[0], rows: rows.slice(2) });
    } else if (LIST_ITEM.test(line)) {
      i = parseList(lines, i, blocks);
    } else {
      const text = [];
      while (i < lines.length && lines[i].trim() !== '' && (text.length === 0 || !startsBlock(lines, i))) text.push(lines[i++].trim());
      blocks.push({ t: 'p', md: text.join('\n') });
    }
  }
  return blocks;
}

const cellsOf = (line) => line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((cell) => cell.trim());

function callout(quoted) {
  const header = CALLOUT.exec(quoted[0] ?? '');
  if (!header) return { t: 'callout', kind: '', title: '', blocks: parseLines(quoted) };
  return { t: 'callout', kind: header[1].toLowerCase(), title: header[2].trim(), blocks: parseLines(quoted.slice(1)) };
}

/** Reads one list starting at line `start`, appends it to `blocks`, returns the next line index. */
function parseList(lines, start, blocks) {
  const [, lead, firstMarker] = LIST_ITEM.exec(lines[start]);
  const base = lead.length;
  const ordered = /\d/.test(firstMarker);
  const items = [];
  const isItem = (line) => {
    const item = LIST_ITEM.exec(line);
    return item && item[1].length === base && /\d/.test(item[2]) === ordered ? item : null;
  };
  let i = start;
  while (i < lines.length) {
    // A blank line between two items does not end the list.
    const gap = lines.slice(i).findIndex((line) => line.trim() !== '');
    if (gap > 0 && isItem(lines[i + gap])) i += gap;
    const item = isItem(lines[i]);
    if (!item) break;
    const body = [item[3]];
    i += 1;
    // Everything indented deeper than the marker belongs to this item, blank lines included.
    while (i < lines.length) {
      if (lines[i].trim() === '') {
        const next = lines.slice(i).findIndex((line) => line.trim() !== '');
        if (next === -1 || indentOf(lines[i + next]) <= base) break;
        body.push('');
        i += 1;
      } else if (indentOf(lines[i]) > base) {
        body.push(lines[i]);
        i += 1;
      } else {
        break;
      }
    }
    const depth = Math.min(...body.slice(1).filter((line) => line.trim() !== '').map(indentOf), Infinity);
    const inner = body.map((line, index) => (index === 0 ? line : line.slice(Math.min(depth, indentOf(line)))));
    let textEnd = 1;
    while (textEnd < inner.length && inner[textEnd].trim() !== '' && !startsBlock(inner, textEnd)) textEnd += 1;
    items.push({ md: inner.slice(0, textEnd).map((line) => line.trim()).join('\n'), blocks: parseLines(inner.slice(textEnd)) });
  }
  blocks.push({ t: 'list', ordered, items });
  return i;
}

/** Markdown text → what a reader sees, for summaries and search. */
export const plainText = (md) => md
  .replace(/`([^`]*)`/g, '$1')
  .replace(/~~([^~]*)~~/g, '$1')
  .replace(/\*+/g, '')
  .replace(/\s+/g, ' ')
  .trim();
