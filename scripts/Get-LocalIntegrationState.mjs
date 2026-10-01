import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, realpathSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const EXPECTED_REPOSITORY = 'Randspringer90/SchachTurnierManager';
const SHA = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;
const MAX_OUTPUT = 4 * 1024 * 1024;
const identity = value => typeof value === 'string' && !/[\s\x00-\x1f\x7f]/.test(value) && /^(?:https:\/\/github\.com\/|git@github\.com:|ssh:\/\/git@github\.com\/)Randspringer90\/SchachTurnierManager(?:\.git)?\/?$/.test(value);
const digest = value => createHash('sha256').update(value).digest('hex');

// -z records preserve filenames containing whitespace/newlines; rename source is
// a separate record, not a second changed file. Never include filenames in output.
export function summarizeStatus(raw) {
  if (typeof raw !== 'string' || (raw && !raw.endsWith('\0'))) throw Error('INVALID_STATUS');
  const records = raw ? raw.slice(0, -1).split('\0') : [];
  const result = { entries: 0, staged: 0, unstaged: 0, untracked: 0, conflicts: 0, renamed: 0, deleted: 0 };
  const conflictStates = new Set(['DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU']);
  for (let i = 0; i < records.length; i++) {
    const record = records[i];
    if (record.length < 4 || record[2] !== ' ') throw Error('INVALID_STATUS');
    const state = record.slice(0, 2);
    if (state === '!!') continue;
    result.entries++;
    if (state === '??') { result.untracked++; continue; }
    if (!/^[ MTADRCU]{2}$/.test(state) || state === '  ') throw Error('INVALID_STATUS');
    if (conflictStates.has(state)) result.conflicts++;
    if (state[0] !== ' ') result.staged++;
    if (state[1] !== ' ') result.unstaged++;
    if (state.includes('D')) result.deleted++;
    if (/[RC]/.test(state)) {
      if (!records[++i]) throw Error('INVALID_STATUS');
      result.renamed++;
    }
  }
  return result;
}

export function isCanonicalRemote(value) {
  return typeof value === 'string' && identity(value);
}

export function inspectLocalState(directory = process.cwd()) {
  // A query error is never converted to a clean checkout or permission to merge.
  const output = {
    schema: 'stm.local-integration-state.v1', repository: EXPECTED_REPOSITORY,
    status: 'UNVERIFIED', complete: false, mergeAuthorized: false,
    remoteObservation: 'LOCAL_TRACKING_REFS_ONLY', activeWriters: 'NOT_DETERMINED',
    contentChangesDuringRead: 'NOT_DETERMINED', errors: [],
  };
  try {
    const requestedRoot = realpathSync(directory);
    // Ignore inherited Git routing/config overrides, not repository policies.
    const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.toUpperCase().startsWith('GIT_')));
    Object.assign(env, { GIT_OPTIONAL_LOCKS: '0', GIT_TERMINAL_PROMPT: '0', LC_ALL: 'C' });
    const git = (args, optional = false) => {
      try {
        const bytes = execFileSync('git', ['-c', 'core.fsmonitor=false', '-c', 'core.untrackedCache=false', ...args], {
          cwd: requestedRoot, env, timeout: 15000, maxBuffer: MAX_OUTPUT,
          windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
        });
        return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
      } catch (error) {
        // Git uses exit 1 for an absent key/ref; all other failures stay explicit.
        if (optional && error?.status === 1) return null;
        throw Error('GIT_QUERY_FAILED');
      }
    };
    if (git(['rev-parse', '--is-inside-work-tree']).trim() !== 'true') throw Error('NOT_A_WORKTREE');
    const root = realpathSync(git(['rev-parse', '--show-toplevel']).trim());
    if (root !== requestedRoot) throw Error('ROOT_REQUIRED');
    const remoteValues = args => git(args).replace(/\r?\n$/, '').split(/\r?\n/);
    const origins = remoteValues(['remote', 'get-url', '--all', 'origin']);
    if (origins.length !== 1 || !identity(origins[0])) throw Error('REPOSITORY_IDENTITY_MISMATCH');
    const pushUrls = remoteValues(['remote', 'get-url', '--push', '--all', 'origin']);
    output.pushTarget = pushUrls.length === 1 && identity(pushUrls[0]) ? 'CANONICAL_EFFECTIVE' : 'NONCANONICAL_OR_MULTIPLE';
    const head = () => {
      const value = git(['rev-parse', '--verify', '--quiet', 'HEAD'], true)?.trim() ?? null;
      if (value !== null && !SHA.test(value)) throw Error('INVALID_HEAD');
      return value;
    };
    const status = () => git(['status', '--porcelain=v1', '-z', '--untracked-files=all', '--ignore-submodules=none']);
    output.head = head();
    const before = status();
    output.changes = summarizeStatus(before);
    output.statusFingerprint = digest(before);
    const branch = git(['symbolic-ref', '--quiet', '--short', 'HEAD'], true)?.trim() ?? null;
    output.branchState = branch === null ? 'DETACHED' : branch === 'development' ? 'DEVELOPMENT' : 'OTHER_BRANCH';
    const reference = git(['rev-parse', '--verify', '--quiet', 'refs/remotes/origin/development'], true)?.trim() ?? null;
    if (reference !== null && !SHA.test(reference)) throw Error('INVALID_REFERENCE');
    output.trackingDevelopment = reference;
    output.aheadBehind = null;
    if (output.head && reference) {
      const counts = git(['rev-list', '--left-right', '--count', 'HEAD...refs/remotes/origin/development']).trim();
      if (!/^\d+\s+\d+$/.test(counts)) throw Error('INVALID_COUNTS');
      const [ahead, behind] = counts.split(/\s+/).map(Number);
      if (![ahead, behind].every(Number.isSafeInteger)) throw Error('INVALID_COUNTS');
      output.aheadBehind = { ahead, behind };
    }
    output.operations = {};
    for (const [label, marker] of Object.entries({ merge: 'MERGE_HEAD', rebaseMerge: 'rebase-merge', rebaseApply: 'rebase-apply', cherryPick: 'CHERRY_PICK_HEAD', revert: 'REVERT_HEAD', indexLock: 'index.lock' })) {
      const path = git(['rev-parse', '--git-path', marker]).trim();
      output.operations[label] = existsSync(resolve(requestedRoot, path));
    }
    const worktrees = git(['worktree', 'list', '--porcelain', '-z']);
    output.worktreeCount = worktrees.split('\0').filter(line => line.startsWith('worktree ')).length;
    if (output.worktreeCount < 1) throw Error('INVALID_WORKTREE_LIST');
    const referenceAfter = git(['rev-parse', '--verify', '--quiet', 'refs/remotes/origin/development'], true)?.trim() ?? null;
    output.metadataChangedDuringRead = output.head !== head() || reference !== referenceAfter || before !== status() ||
      JSON.stringify(origins) !== JSON.stringify(remoteValues(['remote', 'get-url', '--all', 'origin'])) ||
      JSON.stringify(pushUrls) !== JSON.stringify(remoteValues(['remote', 'get-url', '--push', '--all', 'origin']));
    output.complete = !output.metadataChangedDuringRead;
    output.status = output.metadataChangedDuringRead ? 'METADATA_CHANGED' :
      output.changes.conflicts || Object.values(output.operations).some(Boolean) ? 'INTEGRATION_IN_PROGRESS' :
      output.changes.entries ? 'LOCAL_CHANGES_PRESENT' : 'NO_VISIBLE_CHANGES';
  } catch (error) {
    const allowed = new Set(['INVALID_STATUS', 'GIT_QUERY_FAILED', 'NOT_A_WORKTREE', 'ROOT_REQUIRED', 'REPOSITORY_IDENTITY_MISMATCH', 'INVALID_HEAD', 'INVALID_REFERENCE', 'INVALID_COUNTS', 'INVALID_WORKTREE_LIST']);
    output.status = 'UNVERIFIED'; output.complete = false;
    output.errors.push(allowed.has(error?.message) ? error.message : 'LOCAL_INSPECTION_FAILED');
  }
  return output;
}

export function main(args = process.argv.slice(2), stdout = process.stdout, stderr = process.stderr) {
  if (args.length > 1 || args[0]?.startsWith('-')) {
    stderr.write('Usage: node scripts/Get-LocalIntegrationState.mjs [repository-root]\n');
    return 2;
  }
  stderr.write('[LocalIntegration] Reading local Git metadata; no fetch, config write or merge.\n');
  const report = inspectLocalState(args[0]);
  stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  stderr.write(`[LocalIntegration] ${report.status}\n`);
  return report.complete ? 0 : 2;
}

let entry = false;
try { entry = !!process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { /* Imported module. */ }
if (entry) process.exitCode = main();
