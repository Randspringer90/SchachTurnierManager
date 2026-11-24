import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
test('Vite default listener stays on loopback instead of exposing its API proxy', () => {
  const source = readFileSync(new URL('src/SchachTurnierManager.WebApp/vite.config.ts', root), 'utf8');
  assert.match(source, /host:\s*['"]127\.0\.0\.1['"]/);
  assert.doesNotMatch(source, /host:\s*(?:true|['"]0\.0\.0\.0['"])/);
});
test('npm dev explicitly preserves the loopback boundary', () => {
  const manifest = JSON.parse(readFileSync(new URL('src/SchachTurnierManager.WebApp/package.json', root), 'utf8'));
  assert.match(manifest.scripts.dev, /--host\s+127\.0\.0\.1(?:\s|$)/);
  assert.doesNotMatch(manifest.scripts.dev, /--host\s+0\.0\.0\.0/);
});
test('controlled Windows dev launcher does not override Vite with a wildcard bind', () => {
  const source = readFileSync(new URL('scripts/Start-Dev.ps1', root), 'utf8');
  assert.match(source, /'--host',\s*'127\.0\.0\.1'/);
  assert.doesNotMatch(source, /'--host',\s*'0\.0\.0\.0'/);
});
