import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const cases = [
  { provider: 'anthropic', output: JSON.stringify({ type: 'result', is_error: false, result: 'Explain 401 and 429.' }, null, 2), answer: 'Explain 401 and 429.', status: 'ok' },
  { provider: 'anthropic', output: JSON.stringify({ type: 'result', is_error: true, result: 'not logged in' }, null, 2), answer: '', status: 'auth-error' },
  { provider: 'openai', output: [{ type: 'turn.started' }, { type: 'item.completed', item: { type: 'agent_message', text: 'HTTP 429 is an example.' } }, { type: 'turn.completed' }].map(JSON.stringify).join('\n'), answer: 'HTTP 429 is an example.', status: 'ok' },
  { provider: 'openai', output: JSON.stringify({ type: 'turn.failed', error: { message: 'quota exceeded' } }, null, 2), answer: '', status: 'usage-limit' },
  { provider: 'openai', output: 'progress without final answer', answer: '', status: 'ok' },
];
const run = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', String.raw`
$ErrorActionPreference='Stop'
. ./scripts/lib/RoutedExecutionCommon.ps1
$policy=Get-ProviderRuntimePolicy
@(foreach($case in ($env:STM_RUNNER_CASES | ConvertFrom-Json)) {
  [pscustomobject]@{ answer=(Get-RunnerAnswerText -Provider $case.provider -OutputText $case.output)
    status=(Get-RunnerOutputClassification -StructuredOutput $case.output -ExitCode 0 -RuntimePolicy $policy) }
}) | ConvertTo-Json -Compress
`], { cwd: fileURLToPath(new URL('../../', import.meta.url)), encoding: 'utf8', timeout: 20000, windowsHide: true,
  env: { ...process.env, STM_RUNNER_CASES: JSON.stringify(cases) } });
assert.ifError(run.error); assert.equal(run.status, 0, run.stdout + run.stderr);
const actual = JSON.parse(run.stdout);
for (const [index, item] of cases.entries()) test(`structured ${item.provider} result ${index}`, () => {
  assert.equal(actual[index].answer, item.answer); assert.equal(actual[index].status, item.status);
});
