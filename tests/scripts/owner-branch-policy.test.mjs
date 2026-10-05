import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const workflows = new URL('../../.github/workflows/', import.meta.url);
const branchPolicy = readFileSync(new URL('branch-policy.yml', workflows), 'utf8').replace(/\r\n/g, '\n');
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
    const result = spawnSync(process.env.STM_BASH_EXE || 'bash', ['--noprofile', '--norc', '-c', script], {
      encoding: 'utf8', timeout: 5000, windowsHide: true,
      env: { PATH: process.env.PATH, HEAD_REF: head, BASE_REF: base,
        AUTHOR_ASSOCIATION: association, HEAD_REPOSITORY: headRepository, REPOSITORY: canonical }
    });
    assert.ifError(result.error);
    assert.equal(result.status, allowed ? 0 : 1, result.stdout + result.stderr);
  });
}

for (const name of ['ci.yml', 'security-gate.yml', 'pr-static-security-review.yml']) {
  test(`${name}: matching owner pattern and unchanged approval barriers`, () => {
    const source = readFileSync(new URL(name, workflows), 'utf8');
    const pattern = source.match(/\$isOwnerPackage = -not \$AllowBootstrap -and \$env:HEAD_REF -cmatch '([^']+)'/)?.[1];
    assert.ok(pattern);
    const regex = new RegExp(pattern.replace(/^\\A/, '^').replace(/\\z$/, '$'));
    for (const [head, base, association, repository, allowed] of cases.filter(c => c[0].startsWith('owner/'))) {
      const match = regex.exec(head);
      const validName = match !== null && match[0] === head;
      assert.equal(validName && base === 'development' && association === 'OWNER' && repository === canonical, allowed);
    }
    assert.ok(source.includes("$env:AUTHOR_ASSOCIATION -ne 'OWNER' -or $env:HEAD_REPOSITORY -cne $env:REPOSITORY"));
    assert.ok(source.includes('if (-not $isIntegration -and -not $isOwnerPackage -and -not $isBootstrap)'));
    assert.ok(source.includes('if (-not (Test-ShaBoundOwnerReview))'));
    assert.ok(source.includes('[string]$review.user.login -ceq $env:REPOSITORY_OWNER'));
    assert.ok(source.includes('[string]$review.commit_id -ceq $env:EXPECTED_HEAD_SHA'));
    assert.ok(source.includes('([string]$review.body).Trim() -ceq $marker'));
    assert.ok(source.includes("$report.decision -eq 'BLOCKED_UNVERIFIED'"));
    assert.ok(source.includes('ref: ${{ github.event.pull_request.base.sha }}'));
    assert.ok(source.includes('persist-credentials: false'));
    assert.doesNotMatch(source, /^\s+pull_request_target:/m);
    assert.doesNotMatch(source, /^\s+(?:contents|pull-requests): write$/m);
  });
}

for (const name of ['ci.yml', 'security-gate.yml', 'pr-static-security-review.yml']) {
  test(`${name}: canonical existing owner feature branches remain compatible`, () => {
    const source = readFileSync(new URL(name, workflows), 'utf8');
    const pattern = source.match(/\$isOwnerPackage = -not \$AllowBootstrap -and \$env:HEAD_REF -cmatch '([^']+)'/)?.[1];
    const regex = new RegExp(pattern.replace(/^\\A/, '^').replace(/\\z$/, '$'));
    for (const prefix of ['owner', 'feature', 'fix', 'security', 'docs', 'refactor']) {
      const branch = `${prefix}/STM-INFRA-009-pr-readiness`;
      assert.equal(regex.exec(branch)?.[0], branch);
    }
    for (const branch of ['feature/free-form', 'feature/STM-INFRA-9-short', 'feature/STM-INFRA-009-nested/path', 'feature/STM-INFRA-009-trailing\n']) {
      const match = regex.exec(branch);
      assert.ok(!match || match[0] !== branch);
    }
    // Pattern acceptance alone must not bypass identity or current-head approval.
    const ownerCheck = source.indexOf("$env:AUTHOR_ASSOCIATION -ne 'OWNER'");
    assert.ok(ownerCheck >= 0 && ownerCheck < source.indexOf('$isOwnerPackage ='));
    assert.ok(source.indexOf('if (-not (Test-ShaBoundOwnerReview))') > source.indexOf('$isOwnerPackage ='));
  });
}
