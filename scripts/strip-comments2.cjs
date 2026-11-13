const fs = require('fs');
const path = require('path');
const esbuild = require('esbuild');

function stripComments(filepath) {
  const sourceText = fs.readFileSync(filepath, 'utf8');
  if (!sourceText.trim()) return false;

  try {
    const result = esbuild.transformSync(sourceText, {
      loader: 'ts',
      legalComments: 'none',
      format: 'esm',
      target: 'es2022',
    });
    
    if (result.code && result.code !== sourceText) {
      fs.writeFileSync(filepath, result.code + '\n', 'utf8');
      return true;
    }
  } catch (e) {
    console.error(`  ERROR: ${filepath}: ${e.message}`);
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
