import { createHash } from 'node:crypto';

export const MAX_BACKLOG_BYTES = 1024 * 1024;
const STATUSES = ['Backlog', 'Ready', 'In Progress', 'In Review', 'Blocked', 'Done', 'Deferred'];
const HEADER = ['ID', 'Titel', 'Prio', 'Status', 'Kategorie', 'Ziel-Bearb.', 'Issue', 'Release'];
const RELEASE = /^(?:v\d+\.\d+\.\d+|post-\d+\.\d+|development)$/;

export class BacklogFormatError extends Error {
  constructor(code) { super(code); this.name = 'BacklogFormatError'; this.code = code; }
}
const fail = code => { throw new BacklogFormatError(code); };

// GFM table cells: an unescaped pipe is a delimiter, including inside code spans.
function cells(line) {
  const text = line.trim();
  if (!text.startsWith('|') || !text.endsWith('|')) fail('INVALID_TABLE_ROW');
  const result = []; let value = ''; let slashes = 0;
  for (const character of text.slice(1, -1)) {
    if (character === '|' && slashes % 2 === 0) { result.push(value.trim()); value = ''; }
    else value += character;
    slashes = character === '\\' ? slashes + 1 : 0;
  }
  result.push(value.trim());
  if (result.length !== HEADER.length) fail('INVALID_COLUMN_COUNT');
  return result;
}

export function parseBacklog(markdown) {
  if (typeof markdown !== 'string') fail('INVALID_INPUT');
  if (Buffer.byteLength(markdown, 'utf8') > MAX_BACKLOG_BYTES) fail('INPUT_TOO_LARGE');
  // Fenced examples outside the canonical overview are not task declarations.
  const lines = []; let fence = null;
  for (const line of markdown.replace(/^\uFEFF/, '').split(/\r\n|\n|\r/)) {
    const opening = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
    if (fence) {
      if (opening && opening[1][0] === fence[0] && opening[1].length >= fence.length && !opening[2].trim()) fence = null;
      continue;
    }
    if (opening) { fence = opening[1]; continue; }
    lines.push(line);
  }
  if (fence) fail('UNCLOSED_FENCE');
  const starts = lines.flatMap((line, index) => /^##\s+Übersicht\s*$/.test(line) ? [index] : []);
  if (starts.length !== 1) fail('OVERVIEW_NOT_UNIQUE');
  const section = [];
  for (const line of lines.slice(starts[0] + 1)) {
    if (/^#{1,2}\s/.test(line) || /^\s*---+\s*$/.test(line)) break;
    if (line.trim()) section.push(line);
  }
  if (section.length < 3) fail('EMPTY_OVERVIEW');
  if (cells(section[0]).some((value, i) => value !== HEADER[i])) fail('INVALID_HEADER');
  if (cells(section[1]).some(value => !/^:?-{3,}:?$/.test(value))) fail('INVALID_SEPARATOR');
  if (section.length - 2 > 5000) fail('TOO_MANY_TASKS');
  const seen = new Set();
  return section.slice(2).map(line => {
    const [id, , priority, status, , , , release] = cells(line);
    if (!/^STM-[A-Z]+-\d{3}[a-z]?$/.test(id)) fail('INVALID_ID');
    if (seen.has(id)) fail('DUPLICATE_ID');
    seen.add(id);
    if (!/^P[0-3]$/.test(priority)) fail('INVALID_PRIORITY');
    if (!STATUSES.includes(status)) fail('INVALID_STATUS');
    if (!RELEASE.test(release)) fail('INVALID_RELEASE');
    return { id, priority, status, release };
  });
}

function counts(tasks) {
  const byStatus = Object.fromEntries(STATUSES.map(status => [status, 0]));
  for (const task of tasks) byStatus[task.status]++;
  return {
    total: tasks.length, done: byStatus.Done, remaining: tasks.length - byStatus.Done,
    donePercent: tasks.length ? Math.round(byStatus.Done / tasks.length * 10000) / 100 : null,
    byStatus,
  };
}

export function measureBacklog(markdown, release = null) {
  const tasks = parseBacklog(markdown);
  if (release !== null && (typeof release !== 'string' || !RELEASE.test(release))) fail('INVALID_RELEASE_FILTER');
  const selected = release === null ? tasks : tasks.filter(task => task.release === release);
  if (!selected.length) fail('RELEASE_NOT_FOUND');
  return {
    schemaVersion: 'stm-backlog-progress-1',
    sourceSha256: createHash('sha256').update(markdown, 'utf8').digest('hex'),
    measure: 'unweighted-overview-done-status', release,
    summary: counts(selected),
    byRelease: [...new Set(selected.map(task => task.release))].sort().map(name => ({ release: name, ...counts(selected.filter(task => task.release === name)) })),
    remainingIds: selected.filter(task => task.status !== 'Done').map(task => task.id).sort(),
    verification: { gitIntegration: 'NOT_CHECKED', tests: 'NOT_CHECKED', ci: 'NOT_CHECKED', effort: 'NOT_ESTIMATED' },
    mergeAuthorized: false,
  };
}
