import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';

const require = createRequire(new URL('../../../src/SchachTurnierManager.WebApp/package.json', import.meta.url));
const ts = require('typescript');
const source = readFileSync(new URL('../../../src/SchachTurnierManager.WebApp/src/qrcodegen.ts', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS },
}).outputText;

// Execute only the reviewed, dependency-free QR module. No process/require/network bindings.
// VM context injection selects the UTF-8 branch; it is a test harness, not a security sandbox.
export function loadQr(textEncoder = TextEncoder) {
  const exports = {};
  runInNewContext(compiled, { exports, TextEncoder: textEncoder === null ? undefined : textEncoder }, { timeout: 1000 });
  return exports;
}
