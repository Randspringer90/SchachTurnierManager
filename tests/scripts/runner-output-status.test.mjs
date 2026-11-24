import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repository = fileURLToPath(new URL('../../', import.meta.url));
const cases = [
  { name: 'ordinary successful answer with HTTP examples', stdout: '401, 429 and 503 are examples; quota exceeded is a quoted phrase.', exit: 0, expected: 'ok' },
  { name: 'successful answer event', stdout: JSON.stringify({ type: 'result', is_error: false, result: 'HTTP 401 and 429; out of credits' }), exit: 0, expected: 'ok' },
  { name: 'Codex answer item', stdout: JSON.stringify({ type: 'item.completed', item: { type: 'agent_message', text: 'rate limit 429' } }), exit: 0, expected: 'ok' },
  { name: 'successful diagnostics with numbers', stderr: 'Processed 401 files and 429 examples.', exit: 0, expected: 'ok' },
  { name: 'native auth failure', stderr: 'HTTP 401 unauthorized', exit: 1, expected: 'auth-error' },
  { name: 'native rate failure', stderr: 'HTTP 429 too many requests', exit: 1, expected: 'rate-limit' },
  { name: 'native quota failure', stderr: 'insufficient_quota', exit: 2, expected: 'usage-limit' },
  { name: 'native unknown failure', stderr: 'synthetic failure', exit: 17, expected: 'error' },
  { name: 'native failure with ordinary stdout', stdout: '401 files and 429 examples', exit: 17, expected: 'error' },
  { name: 'numeric substrings are not HTTP status', stderr: 'failure processing item 4019 or 14290', exit: 1, expected: 'error' },
  { name: 'Codex structured failure despite zero exit', stdout: JSON.stringify({ type: 'turn.failed', error: { message: 'HTTP 429 rate limit' } }), exit: 0, expected: 'rate-limit' },
  { name: 'Claude structured failure despite zero exit', stdout: JSON.stringify({ type: 'result', subtype: 'error_during_execution', is_error: true, errors: ['not logged in'] }), exit: 0, expected: 'auth-error' },
  { name: 'structured error event', stdout: JSON.stringify({ type: 'error', error: { message: 'quota exceeded' } }), exit: 0, expected: 'usage-limit' },
  { name: 'unknown structured error', stdout: JSON.stringify({ type: 'error', message: 'synthetic failure' }), exit: 0, expected: 'error' },
  { name: 'timeout precedes output', stdout: '401', exit: 1, timeout: true, expected: 'timeout' },
];
const harness = String.raw`
$ErrorActionPreference='Stop'
. ./scripts/lib/RoutedExecutionCommon.ps1
$policy=Get-ProviderRuntimePolicy
$cases=$env:STM_STATUS_CASES | ConvertFrom-Json
@(foreach($case in $cases) {
  Get-RunnerOutputClassification -StructuredOutput ([string]$case.stdout) -ErrorText ([string]$case.stderr) -ExitCode $case.exit -TimedOut:([bool]$case.timeout) -RuntimePolicy $policy
}) | ConvertTo-Json -Compress
`;
const input = cases.map(item => ({ stdout: '', stderr: '', timeout: false, ...item }));
const run = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', harness], {
  cwd: repository, encoding: 'utf8', timeout: 20000, windowsHide: true,
  env: { ...process.env, STM_STATUS_CASES: JSON.stringify(input) },
});
assert.ifError(run.error);
assert.equal(run.status, 0, run.stdout + run.stderr);
const actual = JSON.parse(run.stdout);
for (const [index, item] of cases.entries()) {
  test(item.name, () => assert.equal(actual[index], item.expected));
}
