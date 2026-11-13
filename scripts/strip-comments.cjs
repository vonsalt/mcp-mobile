const fs = require('fs');
const path = require('path');
const ts = require('typescript');

function stripComments(filepath) {
  const sourceText = fs.readFileSync(filepath, 'utf8');
  if (!sourceText.trim()) return false;

  const sourceFile = ts.createSourceFile(
    filepath,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    filepath.endsWith('.tsx') ? ts.ScriptKind.TSX : ts.ScriptKind.TS
  );

  const removals = [];

  function collectComments(ranges) {
    if (!ranges) return;
    for (const range of ranges) {
      removals.push({ start: range.pos, end: range.end });
    }
  }

  function visit(node) {
    const fullStart = node.getFullStart();
    const leadingComments = ts.getLeadingCommentRanges(sourceText, fullStart);
    collectComments(leadingComments);

    const trailingComments = ts.getTrailingCommentRanges(sourceText, node.end);
    collectComments(trailingComments);

    ts.forEachChild(node, visit);
  }

  visit(sourceFile);

  // Also check for comments at the very end of file (after last node)
  const trailingComments = ts.getTrailingCommentRanges(sourceText, sourceText.length);
  collectComments(trailingComments);

  // Also check for leading comments before the first node
  if (sourceFile.statements.length > 0) {
    const firstStart = sourceFile.statements[0].getFullStart();
    const firstLeading = ts.getLeadingCommentRanges(sourceText, firstStart);
    // These should already be collected by visit(), but just in case
    collectComments(firstLeading);
  }

  if (removals.length === 0) return false;

  // Sort by start position descending so we can remove from the end
  removals.sort((a, b) => b.start - a.start);

  let result = sourceText;
  for (const removal of removals) {
    result = result.slice(0, removal.start) + result.slice(removal.end);
  }

  // Clean up: remove consecutive blank lines (max 2 in a row)
  result = result.replace(/\n{4,}/g, '\n\n\n');

  // Remove trailing whitespace lines
  result = result.replace(/\s+$/, '\n');

  if (result !== sourceText) {
    fs.writeFileSync(filepath, result, 'utf8');
    return true;
  }
  return false;
}

function walk(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  let count = 0;
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      count += walk(full);
    } else if (entry.name.endsWith('.ts') && !entry.name.endsWith('.d.ts')) {
      if (stripComments(full)) {
        count++;
        console.log(`  stripped: ${full}`);
      }
    }
  }
  return count;
}

const total = walk('src');
console.log(`\nDone. Stripped comments from ${total} files.`);
