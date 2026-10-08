import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const root = new URL('../../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const policy = JSON.parse(read('config/provider-runtime-policy.json'));
const catalog = JSON.parse(read('config/model-catalog.json'));
const model = (provider, profile) => {
  const binding = policy.providers[provider].profiles[profile];
  assert.equal(Object.hasOwn(binding, 'model'), false, 'model IDs belong only in the catalog');
  assert.equal(catalog.models[binding.modelKey].provider, provider);
  assert.ok(catalog.models[binding.modelKey].id.length > 0);
  return binding.modelKey;
};

for (const [provider, profile, expected] of [
  ['openai', 'sol', 'openaiSol'], ['openai', 'luna', 'openaiSol'], ['openai', 'terra', 'openaiLuna'],
  ['anthropic', 'fabel', 'anthropicFabel'], ['anthropic', 'opus', 'anthropicOpus'], ['anthropic', 'sonnet', 'anthropicSonnet'],
]) test(`reviewed model binding ${provider}/${profile}`, () => assert.equal(model(provider, profile), expected));

test('model review date is explicit, not a claim of runtime availability', () => {
  assert.match(catalog.verifiedOn, /^\d{4}-\d{2}-\d{2}$/);
  assert.equal(catalog.updatePolicy.requireAvailabilityConfirmation, true);
  assert.equal(catalog.updatePolicy.noAutomaticPaidApiSwitch, true);
});
test('logical provider boundaries preserved', () => {
  assert.deepEqual(policy.providerPreference.anthropic, ['fabel', 'opus', 'sonnet']);
  assert.deepEqual(policy.providerPreference.openai, ['sol', 'terra', 'luna']);
});
test('no child write or fallback authorization introduced', () => {
  assert.equal(policy.safety.childrenMayCommit, false);
  assert.equal(policy.safety.childrenMayPush, false);
  assert.equal(policy.safety.noSilentModelSwitch, true);
  assert.equal(policy.safety.unavailableProfileAction, 'block-and-request-explicit-reroute');
});
test('Codex retains explicit readonly sandbox', () => {
  const args = policy.providers.openai.invocation.argumentTemplate;
  assert.equal(args[args.indexOf('--sandbox') + 1], 'read-only');
  assert.ok(!args.some(arg => /danger|bypass/.test(arg)));
});
test('explicit model is in both actual invocation templates', () => {
  for (const provider of Object.values(policy.providers)) {
    assert.equal(provider.invocation.argumentTemplate[provider.invocation.argumentTemplate.indexOf('--model') + 1], '{model}');
    assert.equal(provider.invocation.promptViaStdin, true);
  }
});

// These are SOURCE CONTRACT checks, not execution of PowerShell or a Windows GUI test.
const helper = read('scripts/lib/BackgroundProcess.ps1');
const dev = read('scripts/Start-Dev.ps1');
const click = read('scripts/Invoke-ClickInstallReadiness.ps1');
test('native helper uses both required no-console flags', () => {
  assert.match(helper, /\$startInfo\.UseShellExecute = \$false/);
  assert.match(helper, /\$startInfo\.CreateNoWindow = \$true/);
  assert.match(helper, /WindowStyle = \[Diagnostics\.ProcessWindowStyle\]::Hidden/);
});
test('native argument vector instead of shell command concatenation', () => {
  assert.match(helper, /\$startInfo\.ArgumentList\.Add\(\$argument\)/);
  assert.doesNotMatch(helper, /Invoke-Expression|cmd\.exe|powershell\.exe/);
});
test('output drained concurrently to files and stdin closed', () => {
  assert.equal((helper.match(/BaseStream\.CopyToAsync/g) ?? []).length, 2);
  assert.match(helper, /StandardInput\.Close\(\)/);
  assert.match(helper, /FileMode\]::CreateNew/);
});
test('parent process environment is never written by helper', () => {
  assert.match(helper, /\$startInfo\.Environment\[/);
  assert.doesNotMatch(helper, /\$env:\w+\s*=/);
});
test('cleanup accepts an owned object, not arbitrary PID', () => {
  assert.match(helper, /TypeNames -notcontains 'STM.BackgroundProcess'/);
  assert.match(helper, /\$process\.Kill\(\$true\)/);
  assert.match(helper, /WaitForExit\(10000\)/);
});
test('development starter has no window or browser launch commands', () => {
  assert.doesNotMatch(dev, /Start-Process|Invoke-Item|-NoExit|Start-DevWindow/);
  assert.match(dev, /Start-StmBackgroundProcess/);
  assert.match(dev, /Stop-StmBackgroundProcess/);
});
test('development starter does not silently install new dependencies', () => {
  const executableLines = dev.split('\n').filter(line => !line.trimStart().startsWith('#') && !line.trimStart().startsWith('throw'));
  assert.doesNotMatch(executableLines.join('\n'), /npm\s+install/);
  assert.match(dev, /--strictPort/);
});
test('occupied ports are not assumed to be the right application', () => {
  assert.match(dev, /Assert-DevPortFree 5088/);
  assert.match(dev, /Assert-DevPortFree 5173/);
  assert.match(dev, /No existing process will be reused or stopped/);
});
test('click-install retains health, dashboard and data checks without minimized window', () => {
  assert.doesNotMatch(click, /WindowStyle Minimized|Start-Process/);
  for (const term of ['api/health', 'api/tournaments', "Filter '*.sqlite'", 'Stop-StmBackgroundProcess']) assert.ok(click.includes(term));
  assert.doesNotMatch(click, /\$env:ASPNETCORE_URLS\s*=|Remove-Item Env:/);
});
test('real PowerShell suite is connected to default .NET test discovery', () => {
  const runner = read('tests/SchachTurnierManager.Application.Tests/BackgroundAutomationTests.cs');
  assert.match(runner, /\[Fact\]/);
  assert.match(runner, /Test-BackgroundProcess.ps1/);
  assert.match(runner, /CreateNoWindow = true/);
  assert.match(runner, /UseShellExecute = false/);
  assert.match(runner, /WaitForExitAsync\(deadline.Token\)/);
});
test('real suite covers logs, errors, arguments, EOF and Windows console allocation', () => {
  const suite = read('scripts/Test-BackgroundProcess.ps1');
  for (const expected of ['GetConsoleWindow', '262144', "'-ExitCode', '7'", 'child-only', 'StandardInput', 'Parser]::ParseFile']) {
    assert.ok((suite + helper).includes(expected), expected);
  }
});

test('backend is hosted directly, not through a console-opening run launcher', () => {
  assert.ok(dev.includes("'-getProperty:TargetPath'"));
  assert.ok(dev.includes("@($assembly, '--urls', $backendUrl)"));
  assert.ok(dev.includes("'--no-restore'"));
  assert.doesNotMatch(dev, /@\('run',/);
});
