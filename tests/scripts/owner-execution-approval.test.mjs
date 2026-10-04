import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

// Exercise the actual PowerShell functions from the reviewed workflows with
// synthetic gh responses. No token, network request or PR script is used.
const workflowRoot = new URL('../../.github/workflows/', import.meta.url);
const headSha = 'a'.repeat(40);
const owner = 'synthetic-owner';
const repository = `${owner}/synthetic-repository`;
const approvedReview = { user: { login: owner }, commit_id: headSha,
  body: `STATIC-EXECUTION-APPROVED:${headSha}`, state: 'COMMENTED' };

function extractFunction(source, name) {
  const expression = new RegExp(`^          function ${name}[^\\n]*\\{\\r?\\n[\\s\\S]*?^          \\}`, 'm');
  const definition = source.match(expression)?.[0];
  assert.ok(definition, `Missing literal workflow function: ${name}`);
  return definition.replace(/^          /gm, '');
}

function runPowerShell(script, overrides = {}) {
  // Inherit only OS launch essentials, never GH_TOKEN or other credentials.
  const env = {};
  for (const key of ['PATH', 'SystemRoot', 'TEMP', 'TMP', 'HOME', 'USERPROFILE', 'PSModulePath']) {
    if (process.env[key]) env[key] = process.env[key];
  }
  Object.assign(env, { AUTHOR_ASSOCIATION: 'OWNER', HEAD_REPOSITORY: repository,
    REPOSITORY: repository, REPOSITORY_OWNER: owner, EXPECTED_HEAD_SHA: headSha,
    HEAD_REF: 'owner/STM-INFRA-007-branch-policy',
    SYNTHETIC_REVIEWS: JSON.stringify([[approvedReview]]) }, overrides);
  const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script],
    { encoding: 'utf8', timeout: 10000, windowsHide: true, env });
  assert.ifError(result.error);
  return result;
}

for (const name of ['ci.yml', 'security-gate.yml', 'pr-static-security-review.yml']) {
  const source = readFileSync(new URL(name, workflowRoot), 'utf8');
  const definitions = extractFunction(source, 'Test-ShaBoundOwnerReview') + '\n' +
    extractFunction(source, 'Assert-OwnerExecutionApproval');
  const hasBranchFlag = name !== 'pr-static-security-review.yml';
  const prefix = "$ErrorActionPreference = 'Stop'\nfunction gh { $global:LASTEXITCODE = 0; $env:SYNTHETIC_REVIEWS }\n" + definitions + '\n';
  const invocation = bootstrap => hasBranchFlag
    ? `Assert-OwnerExecutionApproval $true $${bootstrap}` : `Assert-OwnerExecutionApproval $${bootstrap}`;
  const cases = [
    ['owner-current-review', {}, false, true],
    ['existing-feature', { HEAD_REF: 'feature/STM-INFRA-009-pr-readiness' }, false, true],
    ['integration-current-review', { HEAD_REF: 'integration/pr-62-safe-adoption' }, false, true],
    ['contributor', { AUTHOR_ASSOCIATION: 'COLLABORATOR' }, false, false],
    ['fork', { HEAD_REPOSITORY: 'synthetic-fork/repository' }, false, false],
    ['missing-review', { SYNTHETIC_REVIEWS: '[]' }, false, false],
    ['wrong-reviewer', { SYNTHETIC_REVIEWS: JSON.stringify([[{ ...approvedReview, user: { login: 'synthetic-other' } }]]) }, false, false],
    ['stale-review', { SYNTHETIC_REVIEWS: JSON.stringify([[{ ...approvedReview, commit_id: 'b'.repeat(40) }]]) }, false, false],
    ['wrong-marker', { SYNTHETIC_REVIEWS: JSON.stringify([[{ ...approvedReview, body: 'synthetic-nonapproval' }]]) }, false, false],
    ['missing-scanner-owner', {}, true, false],
    ['missing-scanner-integration', { HEAD_REF: 'integration/pr-62-safe-adoption' }, true, false],
    ['exact-bootstrap', { HEAD_REF: 'security/STM-SEC-005-safe-pr-adoption' }, true, true],
    ['bootstrap-without-review', { HEAD_REF: 'security/STM-SEC-005-safe-pr-adoption', SYNTHETIC_REVIEWS: '[]' }, true, false]
  ];
  for (const [label, env, bootstrap, allowed] of cases) {
    test(`${name}: actual PowerShell approval / ${label}`, () => {
      const result = runPowerShell(prefix + invocation(bootstrap) + '\nexit 0', env);
      assert.equal(result.status, allowed ? 0 : 1, result.stdout + result.stderr);
    });
  }
  test(`${name}: actual blocked-static guard throws before execution`, () => {
    const guard = source.match(/^          if \(\$report\.decision -eq 'BLOCKED_UNVERIFIED'\) \{[^\r\n]+/m)?.[0];
    assert.ok(guard);
    const result = runPowerShell("$ErrorActionPreference = 'Stop'\n$report = [pscustomobject]@{decision='BLOCKED_UNVERIFIED'}\n" + guard.trim() + '\nexit 0');
    assert.equal(result.status, 1, result.stdout + result.stderr);
  });
}
