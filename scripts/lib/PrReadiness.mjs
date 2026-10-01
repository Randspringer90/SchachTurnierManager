// STM-INFRA-009. Observation only: never a merge authorizer or a full DoD gate.
export const EXPECTED_CHECKS = Object.freeze([
  'branch-policy', 'pr-static-security', 'security-gate', 'ci-static-prerequisite',
  'agent-integrity', 'diff-check', 'build-test', 'frontend'
]);
const sha = value => typeof value === 'string' && /^[a-f0-9]{40}$/.test(value);
const positive = value => Number.isSafeInteger(value) && value > 0;
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const validTime = value => typeof value === 'string' && Number.isFinite(Date.parse(value));

export function validateRepository(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$/.test(value)) {
    throw new Error('INVALID_REPOSITORY');
  }
  return value;
}

function checkVerdict(check, head) {
  if (!record(check) || !positive(check.id) || check.head_sha !== head || !positive(check.app?.id)) return 'UNKNOWN';
  if (['queued', 'in_progress', 'waiting', 'pending', 'requested'].includes(check.status)) return 'PENDING';
  if (check.status !== 'completed') return 'UNKNOWN';
  if (check.conclusion === 'success') return 'PASS';
  if (['failure', 'cancelled', 'timed_out', 'action_required', 'startup_failure'].includes(check.conclusion)) return 'FAIL';
  if (check.conclusion === 'skipped') return 'SKIPPED';
  if (check.conclusion === 'neutral') return 'NEUTRAL';
  return 'UNKNOWN';
}

function statusVerdicts(statuses) {
  const latest = new Map();
  let invalid = 0;
  for (const status of statuses) {
    if (!record(status) || typeof status.context !== 'string' || !status.context ||
        !positive(status.id) || !validTime(status.created_at)) { invalid++; continue; }
    const previous = latest.get(status.context);
    const later = !previous || Date.parse(status.created_at) > Date.parse(previous.created_at) ||
      (Date.parse(status.created_at) === Date.parse(previous.created_at) && status.id > previous.id);
    if (later) latest.set(status.context, status);
  }
  return [
    ...Array.from(latest.values(), status => ({ success: 'PASS', failure: 'FAIL', error: 'FAIL', pending: 'PENDING' })[status.state] ?? 'UNKNOWN'),
    ...Array(invalid).fill('UNKNOWN')
  ];
}

function reviewState(reviews, head, owner) {
  let ownerExecutionApproval = false;
  let invalid = false;
  let approvalsAtHead = 0;
  let staleApprovals = 0;
  const substantive = new Map();
  for (const review of reviews) {
    if (!record(review) || !positive(review.id) || typeof review.user?.login !== 'string' ||
        !['APPROVED', 'CHANGES_REQUESTED', 'COMMENTED', 'DISMISSED', 'PENDING'].includes(review.state)) {
      invalid = true; continue;
    }
    if (review.state === 'PENDING' || review.state === 'DISMISSED') continue;
    if (!sha(review.commit_id) || !validTime(review.submitted_at)) { invalid = true; continue; }
    if (review.user.login === owner && review.commit_id === head &&
        ['COMMENTED', 'APPROVED'].includes(review.state) && typeof review.body === 'string' &&
        review.body.trim() === `STATIC-EXECUTION-APPROVED:${head}`) ownerExecutionApproval = true;
    if (review.state === 'COMMENTED') continue; // A comment never clears a request for changes.
    const key = review.user.login.toLowerCase();
    const previous = substantive.get(key);
    if (!previous || Date.parse(review.submitted_at) > Date.parse(previous.submitted_at) ||
        (Date.parse(review.submitted_at) === Date.parse(previous.submitted_at) && review.id > previous.id)) substantive.set(key, review);
  }
  let changesRequested = 0;
  for (const review of substantive.values()) {
    if (review.state === 'CHANGES_REQUESTED') changesRequested++;
    else if (review.commit_id === head) approvalsAtHead++;
    else staleApprovals++;
  }
  return { ownerExecutionApproval, changesRequested, approvalsAtHead, staleApprovals, invalid };
}

export function analyzePullRequest(item, repository, developmentSha) {
  const reasons = new Set();
  const incomplete = new Set();
  const number = positive(item?.number) ? item.number : null;
  const basic = { number, url: number ? `https://github.com/${repository}/pull/${number}` : null,
    definitionOfDone: 'NOT_EVALUATED', mergeAuthorized: false };
  if (!record(item) || item.error || !number) return { ...basic, state: 'INCOMPLETE', reasons: ['PR_FETCH_FAILED'] };
  const before = item.before;
  const after = item.after;
  const validPr = pr => record(pr) && pr.number === number && sha(pr.head?.sha) && sha(pr.base?.sha) &&
    typeof pr.draft === 'boolean' && typeof pr.state === 'string' && typeof pr.base.ref === 'string' &&
    typeof pr.head.ref === 'string' && typeof pr.head.repo?.full_name === 'string' &&
    typeof pr.author_association === 'string' && pr.base.repo?.full_name === repository;
  if (!validPr(before) || !validPr(after)) return { ...basic, state: 'INCOMPLETE', reasons: ['INVALID_PR_METADATA'] };
  const head = before.head.sha;
  if (before.head.sha !== after.head.sha || before.base.sha !== after.base.sha || before.base.ref !== after.base.ref ||
      before.head.ref !== after.head.ref || before.head.repo.full_name !== after.head.repo.full_name ||
      before.state !== after.state || before.draft !== after.draft) incomplete.add('PR_CHANGED_DURING_READ');
  if (after.base.ref !== 'development') incomplete.add('UNSUPPORTED_BASE_POLICY');
  if (!sha(developmentSha) || after.base.sha !== developmentSha) incomplete.add('BASE_SNAPSHOT_DIFFERS');
  if (after.state !== 'open') reasons.add('PR_NOT_OPEN');
  if (after.draft) reasons.add('DRAFT');
  if (after.mergeable === false) reasons.add('MERGE_CONFLICT');
  else if (after.mergeable !== true) incomplete.add('MERGEABILITY_UNKNOWN');

  for (const section of ['checks', 'statuses', 'reviews']) {
    if (!record(item[section]) || !Array.isArray(item[section].items) || item[section].complete !== true) incomplete.add('PAGINATION_OR_FETCH_INCOMPLETE');
  }
  const checkRuns = Array.isArray(item.checks?.items) ? item.checks.items : [];
  const checks = EXPECTED_CHECKS.map(name => {
    const matching = checkRuns.filter(check => check?.name === name);
    const verdicts = matching.map(check => checkVerdict(check, head));
    let verdict = 'MISSING';
    if (verdicts.includes('FAIL')) verdict = 'FAIL';
    else if (verdicts.length === 1) verdict = verdicts[0];
    else if (verdicts.length > 1) verdict = 'AMBIGUOUS';
    // A same-named third-party check cannot satisfy the observed GitHub Actions baseline.
    if (verdict === 'PASS' && (matching[0].app.id !== 15368 || matching[0].app.slug !== 'github-actions')) verdict = 'UNKNOWN';
    return { name, verdict };
  });
  const otherVerdicts = checkRuns.filter(check => !EXPECTED_CHECKS.includes(check?.name)).map(check => checkVerdict(check, head));
  const statuses = statusVerdicts(Array.isArray(item.statuses?.items) ? item.statuses.items : []);
  if ([...checks.map(check => check.verdict), ...otherVerdicts, ...statuses].includes('FAIL')) reasons.add('CHECK_FAILED');
  if (checks.some(check => check.verdict !== 'PASS' && check.verdict !== 'FAIL') ||
      [...otherVerdicts, ...statuses].some(verdict => verdict !== 'PASS' && verdict !== 'FAIL')) incomplete.add('CHECKS_NOT_ALL_SUCCESSFUL');
  const reviews = reviewState(Array.isArray(item.reviews?.items) ? item.reviews.items : [], head, repository.split('/')[0]);
  if (reviews.invalid) incomplete.add('INVALID_REVIEW_METADATA');
  if (reviews.changesRequested > 0) reasons.add('CHANGES_REQUESTED');
  // SAFE_FOR_ISOLATED_BUILD does not require an owner marker. Absence alone is not a blocker.
  const ownerExecutionPathApplicable = after.author_association === 'OWNER' && after.head.repo.full_name === repository;
  return { ...basic, head, base: after.base.sha,
    state: reasons.size ? 'BLOCKED' : incomplete.size ? 'INCOMPLETE' : 'OBSERVED_REMOTE_CHECKS_CLEAR',
    reasons: [...reasons, ...incomplete], checks, reviews, ownerExecutionPathApplicable,
    ownerExecutionReviewRequirement: 'NOT_INFERRED_FROM_REVIEW_LIST',
    additionalChecks: { checkRuns: otherVerdicts.length, statuses: statuses.length },
    unverified: ['LOCAL_DOD_GATES', 'CODEOWNERS_APPROVAL', 'REVIEW_THREAD_RESOLUTION', 'EFFECTIVE_BRANCH_PROTECTION', 'INDEPENDENT_CODE_REVIEW'] };
}

export function analyzeSnapshot(snapshot) {
  if (!record(snapshot) || snapshot.schema !== 'stm.pr-readiness.snapshot.v1' || !Array.isArray(snapshot.items)) throw new Error('INVALID_SNAPSHOT');
  const repository = validateRepository(snapshot.repository);
  const reasons = [];
  if (snapshot.discoveryComplete !== true) reasons.push('PR_DISCOVERY_INCOMPLETE');
  if (!sha(snapshot.developmentBefore) || snapshot.developmentBefore !== snapshot.developmentAfter) reasons.push('DEVELOPMENT_CHANGED_OR_UNAVAILABLE');
  const seen = new Set();
  const pullRequests = snapshot.items.map(item => {
    if (seen.has(item?.number)) reasons.push('DUPLICATE_PR_IN_SNAPSHOT');
    seen.add(item?.number);
    return analyzePullRequest(item, repository, snapshot.developmentAfter);
  });
  const state = reasons.length ? 'INCOMPLETE' : pullRequests.some(pr => pr.state === 'BLOCKED') ? 'BLOCKED' :
    pullRequests.some(pr => pr.state === 'INCOMPLETE') ? 'INCOMPLETE' : pullRequests.length ? 'OBSERVED_REMOTE_CHECKS_CLEAR' : 'NO_OPEN_PRS';
  return { schema: 'stm.pr-readiness.report.v1', repository, state, reasons,
    definitionOfDone: 'NOT_EVALUATED', mergeAuthorized: false,
    developmentSha: sha(snapshot.developmentAfter) ? snapshot.developmentAfter : null,
    pullRequests: pullRequests.sort((a, b) => (a.number ?? 0) - (b.number ?? 0)) };
}

/** All requests are relative, fixed GET routes. The injected transport enables offline tests. */
export function collectSnapshot(repository, get, { pageSize = 100, maxPages = 10, maxPullRequests = 50, maxRequests = 300 } = {}) {
  validateRepository(repository);
  for (const value of [pageSize, maxPages, maxPullRequests, maxRequests]) if (!positive(value)) throw new Error('INVALID_LIMIT');
  if (pageSize > 100 || maxPages > 10 || maxPullRequests > 50 || maxRequests > 300) throw new Error('INVALID_LIMIT');
  let requestCount = 0;
  const request = route => {
    if (++requestCount > maxRequests) throw new Error('REQUEST_BUDGET_EXHAUSTED');
    return get(`repos/${repository}/${route}`);
  };
  const paged = (route, key = null) => {
    const items = [];
    for (let page = 1; page <= maxPages; page++) {
      const payload = request(`${route}${route.includes('?') ? '&' : '?'}per_page=${pageSize}&page=${page}`);
      const rows = key ? payload?.[key] : payload;
      if (!Array.isArray(rows) || rows.length > pageSize) throw new Error('INVALID_PAGE');
      items.push(...rows);
      if (rows.length < pageSize) {
        const complete = !key || (Number.isSafeInteger(payload.total_count) && payload.total_count >= 0 && payload.total_count === items.length);
        return { items, complete };
      }
    }
    return { items, complete: false };
  };
  const result = { schema: 'stm.pr-readiness.snapshot.v1', repository, discoveryComplete: false,
    developmentBefore: null, developmentAfter: null, items: [] };
  try { result.developmentBefore = request('git/ref/heads/development')?.object?.sha; } catch { /* Unknown, not green. */ }
  let discovery;
  try { discovery = paged('pulls?state=open&sort=created&direction=asc'); }
  catch { return result; }
  result.discoveryComplete = discovery.complete && discovery.items.length <= maxPullRequests;
  const seen = new Set();
  for (const summary of discovery.items.slice(0, maxPullRequests)) {
    if (!positive(summary?.number) || seen.has(summary.number)) { result.discoveryComplete = false; continue; }
    seen.add(summary.number);
    const item = { number: summary.number };
    try {
      item.before = request(`pulls/${summary.number}`);
      const head = item.before?.head?.sha;
      if (!sha(head)) throw new Error('INVALID_HEAD');
      item.checks = paged(`commits/${head}/check-runs?filter=latest`, 'check_runs');
      item.statuses = paged(`commits/${head}/statuses`);
      item.reviews = paged(`pulls/${summary.number}/reviews`);
      item.after = request(`pulls/${summary.number}`);
    } catch { item.error = 'PR_FETCH_FAILED'; }
    result.items.push(item);
  }
  try { result.developmentAfter = request('git/ref/heads/development')?.object?.sha; } catch { /* Unknown, not green. */ }
  return result;
}
