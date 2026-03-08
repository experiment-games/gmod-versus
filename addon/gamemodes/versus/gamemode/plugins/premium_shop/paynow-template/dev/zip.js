const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

const EXCLUDE = new Set([
  'tailwind.config.js',
  'style.src.css',
  'package.json',
  'package-lock.json',
  'postcss.config.cjs',
  'node_modules',
  'dev',
  '.gitignore',
]);

const ROOT = path.resolve(__dirname, '..');
const OUTPUT = path.join(ROOT, 'paynow-template.zip');

const output = fs.createWriteStream(OUTPUT);
const archive = archiver('zip', { zlib: { level: 9 } });

output.on('close', () => {
  console.log(`Created paynow-template.zip (${archive.pointer()} bytes)`);
});

archive.on('error', (err) => { throw err; });
archive.pipe(output);

function addDir(dir, base) {
  for (const entry of fs.readdirSync(dir)) {
    if (EXCLUDE.has(entry)) continue;
    const abs = path.join(dir, entry);
    const rel = base ? `${base}/${entry}` : entry;
    if (fs.statSync(abs).isDirectory()) {
      addDir(abs, rel);
    } else {
      archive.file(abs, { name: rel });
    }
  }
}

addDir(ROOT, '');
archive.finalize();
