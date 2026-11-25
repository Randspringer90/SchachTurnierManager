import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repository = fileURLToPath(new URL('../../', import.meta.url));
const catalog = JSON.parse(readFileSync(join(repository, 'config/model-catalog.json'), 'utf8'));
const model = catalog.models.localGptOss20b.id;
const cap = 16 * 1024 * 1024;
const scenarios = [
  { name: 'ordinary content is not status', status: 200, body: JSON.stringify({ response: '401 429 out of credits', done: true }), exit: 0, expected: 'ok' },
  { name: 'HTTP auth error', status: 401, body: '{}', exit: 3, expected: 'auth-error' },
  { name: 'HTTP rate error', status: 429, body: '{}', exit: 2, expected: 'rate-limit' },
  { name: 'declared oversized response is rejected before body buffering', declared: cap + 1, exit: 5, expected: 'error' },
  { name: 'unbounded chunked response is stopped at the cap', chunked: true, body: Buffer.alloc(cap + 1, 120), exit: 5, expected: 'error' },
  { name: 'invalid UTF8 is rejected', body: Buffer.from([255]), exit: 5, expected: 'error' },
  { name: 'stalled response body respects the deadline', stall: true, exit: 4, expected: 'timeout' },
  { name: 'oversized prompt is not sent', largePrompt: true, exit: 5, expected: 'HOLD_PROMPT_TOO_LARGE' },
];
for (const scenario of scenarios) test(`synthetic loopback transport: ${scenario.name}`, async () => {
  const directory = mkdtempSync(join(tmpdir(), 'stm-local-transport-'));
  const prompt = join(directory, 'prompt.txt'), output = join(directory, 'answer.txt');
  writeFileSync(prompt, scenario.largePrompt ? 'x'.repeat(1024 * 1024 + 1) : 'Synthetic deterministic test input.');
  const requests = [];
  const server = createServer((request, response) => {
    requests.push(`${request.method} ${request.url}`);
    request.resume(); response.on('error', () => {});
    if (request.url === '/api/tags') {
      response.setHeader('Content-Type', 'application/json');
      response.end(JSON.stringify({ models: [{ name: model, size: 14_000_000_000 }] })); return;
    }
    if (request.url !== '/api/generate') { response.writeHead(404); response.end(); return; }
    response.writeHead(scenario.status ?? 200, { 'Content-Type': 'application/json',
      ...(scenario.declared ? { 'Content-Length': scenario.declared } : {}),
      ...(scenario.chunked ? { 'Transfer-Encoding': 'chunked' } : {}) });
    response.flushHeaders();
    if (!scenario.stall && !scenario.declared) response.end(scenario.body ?? '{}');
  });
  server.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try {
    const child = spawn('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File',
      join(repository, 'scripts/Invoke-LocalModelProfile.ps1'), '-ProfileId', 'local-assist',
      '-PromptFile', prompt, '-OutputFile', output, '-TimeoutSeconds', '1'], {
      cwd: repository, windowsHide: true, env: { ...process.env, OLLAMA_HOST: `127.0.0.1:${server.address().port}` },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '', stderr = '';
    child.stdout.on('data', data => { stdout += data; }); child.stderr.on('data', data => { stderr += data; });
    const timer = setTimeout(() => child.kill(), 15000);
    const code = await new Promise((resolve, reject) => { child.once('error', reject); child.once('close', resolve); });
    clearTimeout(timer);
    assert.equal(code, scenario.exit, stdout + stderr);
    assert.equal(JSON.parse(stdout.trim()).status, scenario.expected, stdout + stderr);
    assert.ok(requests.every(path => ['GET /api/tags', 'POST /api/generate'].includes(path)));
    if (scenario.largePrompt) assert.deepEqual(requests, ['GET /api/tags']);
  } finally {
    server.closeAllConnections(); await new Promise(resolve => server.close(resolve));
    rmSync(directory, { recursive: true, force: true, maxRetries: 3 });
  }
});
