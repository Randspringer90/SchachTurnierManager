import { execFileSync } from 'node:child_process';
import { lstatSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { analyzeSnapshot, collectSnapshot, validateRepository } from './lib/PrReadiness.mjs';

export function createGhReader(run = execFileSync) {
  return endpoint => {
    if (typeof endpoint !== 'string' || !/^repos\/[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+\/(?:pulls(?:\/[1-9][0-9]*(?:\/reviews)?)?|git\/ref\/heads\/development|commits\/[a-f0-9]{40}\/(?:check-runs|statuses))(?:\?[A-Za-z0-9_=&-]+)?$/.test(endpoint)) throw new Error('ENDPOINT_DENIED');
    try {
      const raw = run('gh', ['api', '--hostname', 'github.com', '--method', 'GET', endpoint], {
        encoding: 'utf8', timeout: 20000, maxBuffer: 4 * 1024 * 1024, windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe']
      });
      return JSON.parse(raw);
    } catch { throw new Error('GITHUB_READ_FAILED'); } // Never echo tokens, stderr or response bodies.
  };
}

export function main(argv, { get = createGhReader(), write = text => process.stdout.write(text) } = {}) {
  if (argv.length === 1 && argv[0] === '--help') {
    write('Usage: node scripts/Get-PrReadiness.mjs --repo OWNER/REPO [--snapshot FILE]\nRead-only GET observation, never merge authorization.\n');
    return 0;
  }
  try {
    if (![2, 4].includes(argv.length) || argv[0] !== '--repo' || (argv.length === 4 && argv[2] !== '--snapshot')) throw new Error('INVALID_ARGUMENTS');
    const repository = validateRepository(argv[1]);
    let snapshot;
    const offline = argv.length === 4;
    if (offline) {
      const info = lstatSync(argv[3]);
      if (!info.isFile() || info.isSymbolicLink() || info.size > 4 * 1024 * 1024) throw new Error('INVALID_SNAPSHOT_FILE');
      snapshot = JSON.parse(readFileSync(argv[3], 'utf8'));
      if (snapshot.repository !== repository) throw new Error('SNAPSHOT_REPOSITORY_MISMATCH');
    } else snapshot = collectSnapshot(repository, get);
    const report = { ...analyzeSnapshot(snapshot), source: offline ? 'OFFLINE_UNVERIFIED_INPUT' : 'GITHUB_GET_OBSERVATION' };
    write(JSON.stringify(report, null, 2) + '\n');
    return ['OBSERVED_REMOTE_CHECKS_CLEAR', 'NO_OPEN_PRS'].includes(report.state) ? 0 : 2;
  } catch {
    write(JSON.stringify({ state: 'ERROR', code: 'READINESS_INPUT_OR_READ_FAILED', mergeAuthorized: false, definitionOfDone: 'NOT_EVALUATED' }) + '\n');
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = main(process.argv.slice(2));
