import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// SOURCE CONTRACT tests only. Run Test-BackgroundProcess.ps1 on Windows for
// actual process/console behavior; these checks do not replace that suite.
const root = new URL('../../', import.meta.url);
const source = readFileSync(new URL('scripts/Invoke-LoggingReadiness.ps1', root), 'utf8');
const processSuite = readFileSync(new URL('scripts/Test-BackgroundProcess.ps1', root), 'utf8');

test('logging readiness uses the native no-console helper', () => {
  assert.match(source, /^#requires -Version 7\.0/);
  assert.ok(source.includes(". (Join-Path $PSScriptRoot 'lib/BackgroundProcess.ps1')"));
  assert.match(source, /Start-StmBackgroundProcess -FilePath \$exe/);
  assert.doesNotMatch(source, /\bStart-Process\b|\bInvoke-Item\b/);
});
test('console outputs go to the run log directory', () => {
  assert.match(source, /-LogDirectory \$runDirectory -Name logging-smoke/);
});
test('test environment belongs to the child, not the caller', () => {
  assert.doesNotMatch(source, /\$env:[A-Za-z_]+\s*=|Remove-Item Env:/);
  assert.match(source, /-Environment @\{/);
  assert.match(source, /ASPNETCORE_URLS = "http:\/\/127\.0\.0\.1:\$effectivePort"/);
  assert.match(source, /SchachTurnierManager__DataDirectory = \$dataDirectory/);
  assert.match(source, /SchachTurnierManager__LogDirectory = \$logDirectory/);
});
test('cleanup uses the owned handle from a finally block', () => {
  assert.match(source, /finally\s*\{\s*if \(\$null -ne \$background\)\s*\{\s*Stop-StmBackgroundProcess -Handle \$background/s);
  assert.doesNotMatch(source, /Stop-Process|taskkill/);
});
test('an exited smoke process is not hidden behind HTTP retries', () => {
  assert.match(source, /\$BackgroundHandle\.Process\.HasExited/);
  assert.match(source, /throw "Logging smoke exited with/);
  assert.equal((source.match(/-BackgroundHandle \$background/g) ?? []).length, 4);
});
test('every automated PowerShell invocation is noninteractive', () => {
  const invocations = source.split('\n').filter(line => /\bpwsh(?:\.exe)? -NoLogo/.test(line));
  assert.equal(invocations.length, 4);
  for (const line of invocations) assert.ok(line.includes('-NonInteractive'), line);
  assert.doesNotMatch(source, /-NoExit|\bRead-Host\b|\bShow-Command\b/);
});
test('logging privacy assertions are retained rather than skipped', () => {
  for (const required of [
    "if ($health.logging.file -ne 'enabled')",
    // The public endpoint reports storage type, never an absolute local path.
    "if ([string]$health.logging.storage -ne 'local')",
    'foreach ($privatePath in @($logDirectory, $dataDirectory))',
    "throw 'Health gibt einen absoluten lokalen Pfad preis.'",
    "if ($logFiles.Count -eq 0)",
    "if ($logText -notmatch 'HTTP GET /api/tournaments')",
    "if ($logText -match 'should-not-appear' -or $logText -match '\\?token=')",
  ]) assert.ok(source.includes(required), required);
});
test('existing build and packaging decisions are not silently changed', () => {
  assert.match(source, /-Name 'releasegate-skip-pack'/);
  assert.match(source, /Invoke-ReleaseGate\.ps1 -SkipPack/);
  assert.match(source, /if \(\$BuildDesktop -or -not/);
  assert.match(source, /Publish-DesktopApp\.ps1 -NoZip/);
});
test('runtime suite parses the logging caller as well as the other starters', () => {
  assert.match(processSuite, /@\('scripts\/Start-Dev.ps1', 'scripts\/Invoke-ClickInstallReadiness.ps1', 'scripts\/Invoke-LoggingReadiness.ps1'\)/);
  assert.match(processSuite, /Parser\]::ParseFile/);
  assert.match(processSuite, /GetConsoleWindow/);
});
test('failure evidence and bounded request timeouts remain present', () => {
  assert.match(source, /Invoke-WebRequest[^\n]+-TimeoutSec 2/);
  assert.match(source, /\$deadline = \(Get-Date\)\.AddSeconds\(\$TimeoutSeconds\)/);
  assert.match(source, /Join-Path \$runDirectory 'FAILED.txt'/);
  assert.match(source, /catch \{\s*\$_\.Exception\.ToString\(\)[\s\S]*?Complete-RunBundle\s*throw/);
});
