import { readdirSync, lstatSync, openSync, readSync, closeSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { resolve, join } from 'node:path';
import { parseCatalog, auditCatalogs, CatalogError } from './lib/I18nCatalogAudit.mjs';

export function readCatalogs(directory, ts) {
  const files = readdirSync(directory).filter(name => name.endsWith('.ts')).sort();
  if (files.length > 100) throw new CatalogError('CATALOG_COUNT_LIMIT');
  const catalogs = new Map();
  for (const name of files) {
    if (!/^[a-z]{2}\.ts$/.test(name)) throw new CatalogError('INVALID_CATALOG_FILENAME');
    const path = join(directory, name); const info = lstatSync(path);
    if (!info.isFile() || info.isSymbolicLink()) throw new CatalogError('NON_REGULAR_CATALOG');
    // Bounded read even if a file grows after lstat. Never execute catalogue statements.
    const fd = openSync(path, 'r'); const buffer = Buffer.alloc(262145); let length = 0;
    try {
      while (length < buffer.length) {
        const read = readSync(fd, buffer, length, buffer.length - length, null);
        if (!read) break;
        length += read;
      }
    } finally { closeSync(fd); }
    if (length > 262144) throw new CatalogError('SOURCE_LIMIT');
    let text;
    try { text = new TextDecoder('utf-8', { fatal: true }).decode(buffer.subarray(0, length)); }
    catch { throw new CatalogError('INVALID_UTF8'); }
    catalogs.set(name.slice(0, 2), parseCatalog(text, name.slice(0, 2), ts));
  }
  return catalogs;
}

export function runAudit(args, { load, output, error }) {
  if (args.some(arg => arg !== '--require-complete') || args.length > 1) {
    error('CATALOG_ARGUMENT_ERROR'); return 2;
  }
  try {
    const { catalogs, compilerVersion } = load();
    const report = { ...auditCatalogs(catalogs, { requireComplete: args.includes('--require-complete') }), compilerVersion };
    output(JSON.stringify(report, null, 2)); return report.valid ? 0 : 1;
  } catch (cause) {
    error(cause instanceof CatalogError ? cause.code : 'CATALOG_READ_OR_COMPILER_ERROR'); return 2;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = runAudit(process.argv.slice(2), {
    load: () => {
      const require = createRequire(new URL('../src/SchachTurnierManager.WebApp/package.json', import.meta.url));
      const ts = require('typescript');
      return { catalogs: readCatalogs(fileURLToPath(new URL('../src/SchachTurnierManager.WebApp/src/i18n/locales/', import.meta.url)), ts), compilerVersion: ts.version };
    },
    output: value => process.stdout.write(`${value}\n`), error: code => process.stderr.write(`${code}\n`),
  });
}
