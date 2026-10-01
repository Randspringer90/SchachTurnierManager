import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { EXPECTED_CHECKS, analyzeSnapshot, collectSnapshot, validateRepository } from '../../scripts/lib/PrReadiness.mjs';
import { createGhReader, main } from '../../scripts/Get-PrReadiness.mjs';

const repository = 'example-owner/example-repository';
const head = 'a'.repeat(40);
const base = 'b'.repeat(40);
const otherHead = 'c'.repeat(40);
const stamp = '2026-01-01T12:00:00Z';
const copy = value => structuredClone(value);
function pr(number = 1) {
  return { number, state: 'open', draft: false, mergeable: true, author_association: 'OWNER',
    base: { sha: base, ref: 'development', repo: { full_name: repository } },
    head: { sha: head, ref: 'integration/pr-1-safe-adoption', repo: { full_name: repository } } };
}
function review(id = 1, state = 'COMMENTED', overrides = {}) {
  return { id, state, user: { login: 'example-owner' }, commit_id: head, submitted_at: stamp,
    body: `STATIC-EXECUTION-APPROVED:${head}`, ...overrides };
}
function check(name, id) {
  return { name, id, head_sha: head, status: 'completed', conclusion: 'success', app: { id: 15368, slug: 'github-actions' } };
}
function item(number = 1) {
  return { number, before: pr(number), after: pr(number),
    checks: { items: EXPECTED_CHECKS.map((name, i) => check(name, i + 1)), complete: true },
    statuses: { items: [], complete: true }, reviews: { items: [review()], complete: true } };
}
function snapshot() {
  return { schema: 'stm.pr-readiness.snapshot.v1', repository, developmentBefore: base,
    developmentAfter: base, discoveryComplete: true, items: [item()] };
}
const analyze = change => { const value = snapshot(); change?.(value); return analyzeSnapshot(value); };
const first = change => analyze(change).pullRequests[0];

// Each named case executes the real analyzer with distinct evidence, not a string-presence assertion.
test('all observed remote evidence clears only the remote precheck, never DoD or merge', () => {
  const report = analyze();
  assert.equal(report.state, 'OBSERVED_REMOTE_CHECKS_CLEAR');
  assert.equal(report.definitionOfDone, 'NOT_EVALUATED');
  assert.equal(report.mergeAuthorized, false);
  assert.equal(report.pullRequests[0].mergeAuthorized, false);
  assert.ok(report.pullRequests[0].unverified.includes('CODEOWNERS_APPROVAL'));
});
for (const [name, mutate, reason] of [
  ['draft', s => { s.items[0].before.draft = s.items[0].after.draft = true; }, 'DRAFT'],
  ['conflict', s => { s.items[0].after.mergeable = false; }, 'MERGE_CONFLICT'],
  ['unknown mergeability', s => { s.items[0].after.mergeable = null; }, 'MERGEABILITY_UNKNOWN'],
  ['head drift', s => { s.items[0].after.head.sha = otherHead; }, 'PR_CHANGED_DURING_READ'],
  ['base drift', s => { s.items[0].after.base.sha = otherHead; }, 'BASE_SNAPSHOT_DIFFERS'],
  ['wrong target', s => { s.items[0].before.base.ref = s.items[0].after.base.ref = 'main'; }, 'UNSUPPORTED_BASE_POLICY'],
  ['closed PR', s => { s.items[0].before.state = s.items[0].after.state = 'closed'; }, 'PR_NOT_OPEN'],
  ['review partial page', s => { s.items[0].reviews.complete = false; }, 'PAGINATION_OR_FETCH_INCOMPLETE'],
  ['status partial page', s => { s.items[0].statuses.complete = false; }, 'PAGINATION_OR_FETCH_INCOMPLETE'],
  ['unknown review state', s => { s.items[0].reviews.items[0].state = 'UNRECOGNIZED'; }, 'INVALID_REVIEW_METADATA']
]) {
  test(name, () => { const result = first(mutate); assert.ok(result.reasons.includes(reason)); assert.notEqual(result.state, 'OBSERVED_REMOTE_CHECKS_CLEAR'); });
}
for (const conclusion of ['failure', 'cancelled', 'timed_out', 'action_required', 'startup_failure']) {
  test(`${conclusion} blocks`, () => {
    const result = first(s => { s.items[0].checks.items[0].conclusion = conclusion; });
    assert.equal(result.state, 'BLOCKED'); assert.ok(result.reasons.includes('CHECK_FAILED'));
  });
}
for (const [status, conclusion, expected] of [
  ['completed', 'skipped', 'SKIPPED'], ['completed', 'neutral', 'NEUTRAL'], ['queued', null, 'PENDING'],
  ['in_progress', null, 'PENDING'], ['completed', null, 'UNKNOWN'], ['completed', 'future-state', 'UNKNOWN']
]) {
  test(`${status}/${conclusion} never passes`, () => {
    const result = first(s => { Object.assign(s.items[0].checks.items[0], { status, conclusion }); });
    assert.equal(result.checks[0].verdict, expected); assert.equal(result.state, 'INCOMPLETE');
  });
}
test('absent checks are missing, not success', () => {
  assert.equal(first(s => { s.items[0].checks.items = []; }).checks[0].verdict, 'MISSING');
});
test('wrong-head checks are unknown, not success', () => {
  assert.equal(first(s => { s.items[0].checks.items[0].head_sha = otherHead; }).checks[0].verdict, 'UNKNOWN');
});
test('same named third-party success does not impersonate Actions', () => {
  assert.equal(first(s => { s.items[0].checks.items[0].app = { id: 2, slug: 'synthetic' }; }).checks[0].verdict, 'UNKNOWN');
});
test('second app cannot hide a failing same-named check', () => {
  const result = first(s => { s.items[0].checks.items.push({ ...check(EXPECTED_CHECKS[0], 100), conclusion: 'failure', app: { id: 2 } }); });
  assert.equal(result.checks[0].verdict, 'FAIL');
});
test('multiple successful runs are ambiguous rather than guessed', () => {
  const result = first(s => { s.items[0].checks.items.push(check(EXPECTED_CHECKS[0], 100)); });
  assert.equal(result.checks[0].verdict, 'AMBIGUOUS');
});
test('failure of an extra check is not hidden', () => {
  const result = first(s => { s.items[0].checks.items.push({ ...check('additional', 100), conclusion: 'failure' }); });
  assert.equal(result.state, 'BLOCKED');
});
test('status failure alongside successful check-runs blocks', () => {
  const result = first(s => { s.items[0].statuses.items = [{ id: 1, context: 'synthetic', state: 'error', created_at: stamp }]; });
  assert.equal(result.state, 'BLOCKED');
});
test('latest status supersedes an older status, regardless of array order', () => {
  const result = first(s => { s.items[0].statuses.items = [
    { id: 2, context: 'synthetic', state: 'success', created_at: '2026-01-02T12:00:00Z' },
    { id: 1, context: 'synthetic', state: 'failure', created_at: stamp }
  ]; });
  assert.equal(result.state, 'OBSERVED_REMOTE_CHECKS_CLEAR');
});
test('invalid status metadata never vanishes', () => {
  assert.equal(first(s => { s.items[0].statuses.items = [{ id: 1, context: 'synthetic', state: 'success' }]; }).state, 'INCOMPLETE');
});
test('comments do not clear a request for changes', () => {
  const result = first(s => { s.items[0].reviews.items.push(
    review(2, 'CHANGES_REQUESTED', { user: { login: 'example-reviewer' }, body: 'synthetic' }),
    review(3, 'COMMENTED', { user: { login: 'example-reviewer' }, body: 'synthetic', submitted_at: '2026-01-02T12:00:00Z' })); });
  assert.ok(result.reasons.includes('CHANGES_REQUESTED'));
});
test('later approval by the same reviewer resolves request for changes', () => {
  const result = first(s => { s.items[0].reviews.items.push(
    review(2, 'CHANGES_REQUESTED', { user: { login: 'example-reviewer' } }),
    review(3, 'APPROVED', { user: { login: 'example-reviewer' }, submitted_at: '2026-01-02T12:00:00Z' })); });
  assert.equal(result.reviews.changesRequested, 0); assert.equal(result.reviews.approvalsAtHead, 1);
});
test('stale substantive approvals are reported separately', () => {
  const result = first(s => { s.items[0].reviews.items.push(review(2, 'APPROVED', { commit_id: otherHead, user: { login: 'example-reviewer' } })); });
  assert.equal(result.reviews.staleApprovals, 1); assert.equal(result.reviews.approvalsAtHead, 0);
});
for (const [name, mutate, reason] of [
  ['development moves', s => { s.developmentAfter = otherHead; }, 'DEVELOPMENT_CHANGED_OR_UNAVAILABLE'],
  ['discovery partial', s => { s.discoveryComplete = false; }, 'PR_DISCOVERY_INCOMPLETE'],
  ['duplicate PR', s => { s.items.push(copy(s.items[0])); }, 'DUPLICATE_PR_IN_SNAPSHOT']
]) test(name, () => { const result = analyze(mutate); assert.equal(result.state, 'INCOMPLETE'); assert.ok(result.reasons.includes(reason)); });
test('empty complete discovery is not full DoD', () => {
  const result = analyze(s => { s.items = []; }); assert.equal(result.state, 'NO_OPEN_PRS'); assert.equal(result.mergeAuthorized, false);
});
test('report does not retain titles, bodies, emails or arbitrary raw errors', () => {
  const sensitive = 'SYNTHETIC_PRIVATE_PAYLOAD';
  const result = analyze(s => { s.items[0].before.title = sensitive; s.items[0].before.user = { email: sensitive }; s.items[0].reviews.items.push(review(2, 'COMMENTED', { body: sensitive, user: { login: sensitive } })); });
  assert.ok(!JSON.stringify(result).includes(sensitive));
});
test('malformed snapshots fail closed', () => {
  for (const value of [null, {}, { schema: 'wrong', repository, items: [] }]) assert.throws(() => analyzeSnapshot(value));
});
for (const value of ['../repo', 'owner/../repo', '-owner/repo', 'owner/repo?x=1', 'https://example.invalid/repo', 'owner/repo\n', 'owner/repo;id']) {
  test(`reject repository ${JSON.stringify(value)}`, () => assert.throws(() => validateRepository(value)));
}

function fakeReader({ failNumber = null, drift = false } = {}) {
  const calls = [];
  const reads = new Map();
  const fixture = item();
  const get = endpoint => {
    calls.push(endpoint);
    if (endpoint.endsWith('git/ref/heads/development')) return { object: { sha: base } };
    const url = new URL('https://api.github.com/' + endpoint);
    if (url.pathname.endsWith('/pulls')) return [{ number: 1 }, { number: 2 }];
    const numberMatch = url.pathname.match(/\/pulls\/([0-9]+)$/);
    if (numberMatch) {
      const n = Number(numberMatch[1]);
      if (n === failNumber) throw new Error('SYNTHETIC_SECRET_ERROR');
      reads.set(n, (reads.get(n) ?? 0) + 1);
      const value = pr(n);
      if (drift && reads.get(n) > 1) value.head.sha = otherHead;
      return value;
    }
    if (url.pathname.endsWith('/check-runs')) return { total_count: 8, check_runs: copy(fixture.checks.items) };
    if (url.pathname.endsWith('/statuses')) return [];
    if (url.pathname.endsWith('/reviews')) return copy(fixture.reviews.items);
    throw new Error('UNEXPECTED_ROUTE');
  };
  return { get, calls };
}
test('collector reads both PRs twice, plus checks, statuses and reviews', () => {
  const reader = fakeReader(); const collected = collectSnapshot(repository, reader.get);
  assert.equal(analyzeSnapshot(collected).state, 'OBSERVED_REMOTE_CHECKS_CLEAR');
  assert.equal(collected.items.length, 2); assert.equal(reader.calls.length, 13);
  assert.ok(reader.calls.every(route => route.startsWith(`repos/${repository}/`)));
});
test('collector preserves other PRs if one retrieval fails', () => {
  const reader = fakeReader({ failNumber: 1 }); const result = analyzeSnapshot(collectSnapshot(repository, reader.get));
  assert.equal(result.state, 'INCOMPLETE'); assert.equal(result.pullRequests[1].state, 'OBSERVED_REMOTE_CHECKS_CLEAR');
  assert.ok(!JSON.stringify(result).includes('SYNTHETIC_SECRET_ERROR'));
});
test('collector detects head changes during collection', () => {
  const reader = fakeReader({ drift: true }); const result = analyzeSnapshot(collectSnapshot(repository, reader.get));
  assert.equal(result.state, 'INCOMPLETE');
});
test('collector detects clipped check pagination', () => {
  const reader = fakeReader();
  const get = route => route.includes('/check-runs?') ? { total_count: 9, check_runs: item().checks.items } : reader.get(route);
  assert.equal(analyzeSnapshot(collectSnapshot(repository, get)).state, 'INCOMPLETE');
});
test('collector respects PR and request caps', () => {
  const reader = fakeReader();
  assert.equal(collectSnapshot(repository, reader.get, { maxPullRequests: 1 }).discoveryComplete, false);
  const limited = collectSnapshot(repository, reader.get, { maxRequests: 2 });
  assert.equal(analyzeSnapshot(limited).state, 'INCOMPLETE');
});
test('collector pages discovery instead of silently accepting first page', () => {
  const reader = fakeReader();
  const get = route => {
    if (route.includes('/pulls?')) return new URL('https://api.github.com/' + route).searchParams.get('page') === '1' ? [{ number: 1 }, { number: 2 }] : [];
    if (route.includes('/check-runs?')) {
      const page = Number(new URL('https://api.github.com/' + route).searchParams.get('page'));
      return { total_count: 8, check_runs: item().checks.items.slice((page - 1) * 2, page * 2) };
    }
    return reader.get(route);
  };
  const result = collectSnapshot(repository, get, { pageSize: 2 });
  assert.equal(result.discoveryComplete, true); assert.equal(analyzeSnapshot(result).state, 'OBSERVED_REMOTE_CHECKS_CLEAR');
});
test('collector maximum pages and discovery failure are explicitly incomplete', () => {
  assert.equal(collectSnapshot(repository, () => { throw new Error('SYNTHETIC'); }).discoveryComplete, false);
  const result = collectSnapshot(repository, route => route.includes('/pulls?') ? [{ number: 1 }] : fakeReader().get(route), { pageSize: 1, maxPages: 1 });
  assert.equal(result.discoveryComplete, false);
});
test('gh adapter uses argument array, explicit GET, fixed host and limits', () => {
  let called = false;
  const get = createGhReader((file, argv, options) => {
    called = true; assert.equal(file, 'gh');
    assert.deepEqual(argv.slice(0, 5), ['api', '--hostname', 'github.com', '--method', 'GET']);
    assert.equal(options.timeout, 20000); assert.equal(options.maxBuffer, 4 * 1024 * 1024);
    assert.ok(!options.shell); assert.deepEqual(options.stdio, ['ignore', 'pipe', 'pipe']); return '{}';
  });
  get(`repos/${repository}/pulls?state=open&per_page=100&page=1`); assert.equal(called, true);
  for (const route of ['https://example.invalid', `repos/${repository}/pulls/1/merge`, `repos/${repository}/actions/runs/1/rerun`, `repos/${repository}/../../user`]) assert.throws(() => get(route), /ENDPOINT_DENIED/);
});
test('gh adapter never exposes child stderr or invalid JSON payloads', () => {
  for (const run of [() => { throw new Error('SYNTHETIC_PRIVATE_PAYLOAD'); }, () => 'SYNTHETIC_PRIVATE_PAYLOAD']) {
    assert.throws(() => createGhReader(run)(`repos/${repository}/pulls`), { message: 'GITHUB_READ_FAILED' });
  }
});
test('CLI live adapter returns sanitized report and appropriate exit codes', () => {
  let output = ''; const reader = fakeReader();
  assert.equal(main(['--repo', repository], { get: reader.get, write: text => { output += text; } }), 0);
  assert.equal(JSON.parse(output).source, 'GITHUB_GET_OBSERVATION');
  output = ''; assert.equal(main(['--repo', repository], { get: () => { throw new Error('synthetic'); }, write: text => { output += text; } }), 2);
  assert.equal(JSON.parse(output).state, 'INCOMPLETE');
});
test('CLI offline reads fixtures only and labels them unverified', () => {
  const dir = mkdtempSync(join(tmpdir(), 'stm-pr-readiness-'));
  try {
    const file = join(dir, 'snapshot.json'); writeFileSync(file, JSON.stringify(snapshot()));
    let output = '';
    const code = main(['--repo', repository, '--snapshot', file], { get: () => { throw new Error('must not request'); }, write: text => { output += text; } });
    assert.equal(code, 0); assert.equal(JSON.parse(output).source, 'OFFLINE_UNVERIFIED_INPUT');
    assert.equal(JSON.parse(output).mergeAuthorized, false);
    writeFileSync(file, JSON.stringify({ ...snapshot(), repository: 'different-owner/repository' }));
    output = '';
    assert.equal(main(['--repo', repository, '--snapshot', file], { write: text => { output += text; } }), 1);
    assert.ok(!output.includes(dir));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
test('CLI rejects mutation flags and unsafe input without raw echoes', () => {
  for (const argv of [[], ['--repo', repository, '--merge', '1'], ['--repo', 'private/path/../../../SYNTHETIC']]) {
    let output = ''; assert.equal(main(argv, { write: text => { output += text; } }), 1); assert.ok(!output.includes('SYNTHETIC'));
  }
});

for (const [name, mutate] of [
  ['missing', s => { s.items[0].reviews.items = []; }],
  ['stale', s => { s.items[0].reviews.items[0].commit_id = otherHead; }],
  ['wrong author', s => { s.items[0].reviews.items[0].user.login = 'example-contributor'; }],
  ['dismissed', s => { s.items[0].reviews.items[0].state = 'DISMISSED'; }],
  ['near-match', s => { s.items[0].reviews.items[0].body += '\nextra'; }]
]) test(`owner marker ${name}: absence is observed, not falsely required`, () => {
  const result = first(mutate);
  assert.equal(result.reviews.ownerExecutionApproval, false);
  assert.equal(result.state, 'OBSERVED_REMOTE_CHECKS_CLEAR');
  assert.equal(result.ownerExecutionReviewRequirement, 'NOT_INFERRED_FROM_REVIEW_LIST');
  assert.equal(result.mergeAuthorized, false);
});
test('green contributor PR does not falsely require owner execution path', () => {
  const result = first(s => {
    s.items[0].before.author_association = s.items[0].after.author_association = 'COLLABORATOR';
    s.items[0].before.head.repo.full_name = s.items[0].after.head.repo.full_name = 'example-fork/repository';
    s.items[0].reviews.items = [];
  });
  assert.equal(result.ownerExecutionPathApplicable, false);
  assert.equal(result.state, 'OBSERVED_REMOTE_CHECKS_CLEAR');
});
test('status ties use parsed time and id rather than date string spelling', () => {
  const result = first(s => { s.items[0].statuses.items = [
    { id: 1, context: 'synthetic', state: 'success', created_at: '2026-01-01T12:00:00Z' },
    { id: 2, context: 'synthetic', state: 'failure', created_at: '2026-01-01T12:00:00.000Z' }
  ]; });
  assert.equal(result.state, 'BLOCKED');
});
test('green status cannot replace a missing expected GitHub Actions check', () => {
  const result = first(s => {
    s.items[0].checks.items.shift();
    s.items[0].statuses.items = [{ id: 1, context: EXPECTED_CHECKS[0], state: 'success', created_at: stamp }];
  });
  assert.equal(result.checks[0].verdict, 'MISSING');
  assert.equal(result.state, 'INCOMPLETE');
});
