import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const workflows = new URL('../../.github/workflows/', import.meta.url);
// Windows checkouts may use CRLF; the contracts below are line-ending independent.
const readWorkflow = name => readFileSync(new URL(name, workflows), 'utf8').replace(/\r\n/g, '\n');
const branchPolicy = readWorkflow('branch-policy.yml');
const runBlock = branchPolicy.match(/        run: \|\n((?:          .*\n|\n)+)/)?.[1];
assert.ok(runBlock, 'Branch policy must contain a literal Bash run block.');
const script = runBlock.replace(/^          /gm, '');
const canonical = 'example-owner/example-repository';
const cases = [
  ['owner/STM-INFRA-007-branch-policy', 'development', 'OWNER', canonical, true],
  ['owner/STM-SEC-002-supply-chain', 'development', 'OWNER', canonical, true],
  ['owner/STM-INFRA-007-branch-policy', 'development', 'COLLABORATOR', canonical, false],
  ['owner/STM-INFRA-007-branch-policy', 'development', 'OWNER', 'example-fork/repository', false],
  ['owner/STM-INFRA-007-branch-policy', 'development', '', canonical, false],
  ['owner/STM-INFRA-007-branch-policy', 'main', 'OWNER', canonical, false],
  ['owner/STM-INFRA-007-branch-policy', 'release/1.0.0', 'OWNER', canonical, false],
  ['owner/STM-INFRA-007-', 'development', 'OWNER', canonical, false],
  ['owner/STM-INFRA-007-Bad', 'development', 'OWNER', canonical, false],
  ['owner/STM-INFRA-7-short', 'development', 'OWNER', canonical, false],
  ['owner/STM-INFRA-007-nested/path', 'development', 'OWNER', canonical, false],
  ['owner/STM-INFRA-007-two--hyphens', 'development', 'OWNER', canonical, false],
  ['owner/STM-INFRA-007-trailing\n', 'development', 'OWNER', canonical, false],
  ['owner/STM-INFRA-007-$(exit 0)', 'development', 'OWNER', canonical, false],
  ['feature/STM-UX-001-language', 'development', 'COLLABORATOR', canonical, true],
  ['fix/STM-INFRA-005-temp', 'development', 'COLLABORATOR', canonical, true],
  ['integration/pr-62-safe-adoption', 'development', 'OWNER', canonical, true],
  ['integration/pr-0-safe-adoption', 'development', 'OWNER', canonical, false],
  ['release/1.0.0', 'main', 'OWNER', canonical, true],
  ['hotfix/1.0.1-fix', 'main', 'OWNER', canonical, true],
  ['feature/STM-UX-001-language', 'main', 'OWNER', canonical, false],
  ['development', 'release/1.0.0', 'OWNER', canonical, true],
  ['release-fix/repair', 'release/1.0.0', 'OWNER', canonical, true],
  ['development', 'unexpected-target', 'OWNER', canonical, false]
];

for (const [head, base, association, headRepository, allowed] of cases) {
  test(`Bash policy: ${JSON.stringify(head)} -> ${base} / ${association || 'missing'}`, () => {
    const result = spawnSync('bash', ['--noprofile', '--norc', '-c', script], {
      encoding: 'utf8', timeout: 5000,
      env: { PATH: process.env.PATH, HEAD_REF: head, BASE_REF: base,
        AUTHOR_ASSOCIATION: association, HEAD_REPOSITORY: headRepository, REPOSITORY: canonical }
    });
    assert.ifError(result.error);
    assert.equal(result.status, allowed ? 0 : 1, result.stdout + result.stderr);
  });
}

const gateWorkflows = ['ci.yml', 'security-gate.yml', 'pr-static-security-review.yml'];
const ownerPattern = source => {
  const pattern = source.match(/\$isOwnerPackage = \$env:HEAD_REF -cmatch '([^']+)'/)?.[1];
  assert.ok(pattern, 'owner package pattern missing');
  return new RegExp(pattern.replace(/^\\A/, '^').replace(/\\z$/, '$'));
};
const fullMatch = (regex, value) => regex.exec(value)?.[0] === value;

for (const name of gateWorkflows) {
  test(`${name}: only owner/STM-... is an owner package branch`, () => {
    const regex = ownerPattern(readWorkflow(name));
    for (const branch of ['owner/STM-INFRA-007-branch-policy', 'owner/STM-SEC-002-supply-chain']) assert.ok(fullMatch(regex, branch), branch);
    // The general contributor prefixes must never become an owner execution path.
    for (const prefix of ['feature', 'fix', 'security', 'docs', 'refactor', 'integration', 'Owner']) {
      assert.ok(!fullMatch(regex, `${prefix}/STM-INFRA-009-pr-readiness`), prefix);
    }
    for (const branch of ['owner/free-form', 'owner/STM-INFRA-9-short', 'owner/STM-INFRA-009-nested/path', 'owner/STM-INFRA-009-trailing\n']) {
      assert.ok(!fullMatch(regex, branch), JSON.stringify(branch));
    }
  });
}

// Extracts a PowerShell function definition (balanced braces) from the workflow text.
function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}`);
  assert.ok(start >= 0, `${name} missing`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let index = open; index < source.length; index++) {
    if (source[index] === '{') depth++;
    else if (source[index] === '}' && --depth === 0) return source.slice(start, index + 1);
  }
  throw new Error(`${name} unbalanced`);
}

const head = 'a'.repeat(40);
const other = 'b'.repeat(40);
const review = (overrides = {}) => ({ user: { login: 'example-owner' }, commit_id: head, state: 'COMMENTED',
  body: `STATIC-EXECUTION-APPROVED:${head}`, ...overrides });
const base = { HEAD_REF: 'owner/STM-INFRA-007-branch-policy', AUTHOR_ASSOCIATION: 'OWNER', HEAD_REPOSITORY: canonical,
  ghExit: 0, reviews: JSON.stringify([[review()]]) };
const approvalCases = [
  ['owner package with exact marker', {}, true],
  ['approved state also counts', { reviews: JSON.stringify([[review({ state: 'APPROVED' })]]) }, true],
  ['marker surrounded by whitespace', { reviews: JSON.stringify([[review({ body: `  STATIC-EXECUTION-APPROVED:${head}\n` })]]) }, true],
  ['marker on a later page', { reviews: JSON.stringify([[review({ commit_id: other })], [review()]]) }, true],
  ['integration branch with marker', { HEAD_REF: 'integration/pr-62-safe-adoption' }, true],
  ['feature branch is no owner package', { HEAD_REF: 'feature/STM-INFRA-009-pr-readiness' }, false],
  ['security branch is no owner package', { HEAD_REF: 'security/STM-SEC-006-player-csv-safety' }, false],
  ['bootstrap branch without bootstrap permission', { HEAD_REF: 'security/STM-SEC-005-safe-pr-adoption' }, false],
  ['collaborator author', { AUTHOR_ASSOCIATION: 'COLLABORATOR' }, false],
  ['fork head repository', { HEAD_REPOSITORY: 'example-fork/example-repository' }, false],
  ['review by someone else', { reviews: JSON.stringify([[review({ user: { login: 'someone-else' } })]]) }, false],
  ['owner login differs in case', { reviews: JSON.stringify([[review({ user: { login: 'Example-Owner' } })]]) }, false],
  ['marker on a stale commit', { reviews: JSON.stringify([[review({ commit_id: other })]]) }, false],
  ['marker for another sha', { reviews: JSON.stringify([[review({ body: `STATIC-EXECUTION-APPROVED:${other}` })]]) }, false],
  ['changes requested state', { reviews: JSON.stringify([[review({ state: 'CHANGES_REQUESTED' })]]) }, false],
  ['gh failure is not approval', { ghExit: 1 }, false],
  ['unparseable review payload', { reviews: 'not-json' }, false],
  ['no reviews', { reviews: '[[]]' }, false]
];

for (const name of gateWorkflows) {
  test(`${name}: approval functions behave as specified when executed`, () => {
    const source = readWorkflow(name);
    const harness = [
      "$ErrorActionPreference = 'Stop'",
      // Fake gh: returns the fixture payload and the fixture exit code, never touches the network.
      'function gh { $global:LASTEXITCODE = [int]$env:FAKE_GH_EXIT; if ($env:FAKE_GH_EXIT -ne "0") { return }; $env:FAKE_GH_REVIEWS }',
      extractFunction(source, 'Test-ShaBoundOwnerReview'),
      extractFunction(source, 'Assert-OwnerExecutionApproval'),
      '$parameters = @((Get-Command Assert-OwnerExecutionApproval).Parameters.Keys)',
      "try { if ($parameters -contains 'RequireIntegrationBranch') { Assert-OwnerExecutionApproval $true $false } else { Assert-OwnerExecutionApproval $false }; 'RESULT=ALLOWED' } catch { 'RESULT=DENIED' }"
    ].join('\n');
    const directory = mkdtempSync(join(tmpdir(), 'stm-owner-gate-'));
    const harnessPath = join(directory, 'harness.ps1');
    writeFileSync(harnessPath, harness, 'utf8');
    try {
    for (const [label, overrides, allowed] of approvalCases) {
      const fixture = { ...base, ...overrides };
      const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', harnessPath], {
        encoding: 'utf8', timeout: 30000,
        env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot, TEMP: process.env.TEMP, TMP: process.env.TMP,
          HOME: process.env.HOME, USERPROFILE: process.env.USERPROFILE,
          REPOSITORY: canonical, REPOSITORY_OWNER: 'example-owner', PR_NUMBER: '7', EXPECTED_HEAD_SHA: head,
          HEAD_REF: fixture.HEAD_REF, AUTHOR_ASSOCIATION: fixture.AUTHOR_ASSOCIATION, HEAD_REPOSITORY: fixture.HEAD_REPOSITORY,
          FAKE_GH_EXIT: String(fixture.ghExit), FAKE_GH_REVIEWS: fixture.reviews }
      });
      assert.ifError(result.error);
      assert.match(result.stdout, allowed ? /RESULT=ALLOWED/ : /RESULT=DENIED/, `${name} / ${label}: ${result.stdout}${result.stderr}`);
    }
    } finally { rmSync(directory, { recursive: true, force: true }); }
  });
}

for (const name of gateWorkflows) {
  test(`${name}: approval barriers and workflow hardening stay in place`, () => {
    const source = readWorkflow(name);
    const ownerCheck = source.indexOf("$env:AUTHOR_ASSOCIATION -ne 'OWNER'");
    assert.ok(ownerCheck >= 0 && ownerCheck < source.indexOf('$isOwnerPackage ='));
    assert.ok(source.indexOf('if (-not (Test-ShaBoundOwnerReview))') > source.indexOf('$isOwnerPackage ='));
    assert.ok(source.includes("$report.decision -eq 'BLOCKED_UNVERIFIED'"));
    assert.ok(source.includes('ref: ${{ github.event.pull_request.base.sha }}'));
    assert.ok(source.includes('persist-credentials: false'));
    assert.doesNotMatch(source, /^\s+pull_request_target:/m);
    assert.doesNotMatch(source, /^\s+(?:contents|pull-requests): write$/m);
  });
}
