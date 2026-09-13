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

  const printer = ts.createPrinter({ removeComments: true });
  const result = printer.printFile(sourceFile);

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
