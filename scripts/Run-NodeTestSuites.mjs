import { lstatSync, readdirSync, realpathSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

// Only top-level repository test suites, never fixtures or another directory.
const TEST_NAME = /\.test\.(?:mjs|cjs|js|ts|mts|cts)$/;
const MAX_SUITES = 256;
const MAX_ARGUMENT_CHARS = 24000;
const ROOT = fileURLToPath(new URL('../', import.meta.url));

export class TestSuiteError extends Error {
  constructor(code) { super(code); this.name = 'TestSuiteError'; this.code = code; }
}
const fail = code => { throw new TestSuiteError(code); };

export function requireNode(version) {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(version);
  if (!match || +match[1] < 22 || (+match[1] === 22 && +match[2] < 6)) fail('NODE_22_6_REQUIRED');
}

export function discoverSuites(repositoryRoot) {
  const root = realpathSync(repositoryRoot);
  let directory = root;
  for (const part of ['tests', 'scripts']) {
    directory = join(directory, part);
    const entry = lstatSync(directory);
    if (entry.isSymbolicLink() || !entry.isDirectory()) fail('UNSAFE_TEST_DIRECTORY');
  }
  const files = [];
  const names = new Set();
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (!TEST_NAME.test(entry.name)) continue;
    if (!entry.isFile() || entry.isSymbolicLink()) fail('UNSAFE_TEST_FILE');
    // Case collisions would select a different test set on Windows.
    const folded = entry.name.toLowerCase();
    if (names.has(folded)) fail('CASE_COLLIDING_TEST_FILES');
    names.add(folded);
    const path = join(directory, entry.name);
    if (realpathSync(path) !== path) fail('UNSAFE_TEST_FILE');
    files.push(relative(root, path).split(sep).join('/'));
  }
  if (!files.length) fail('NO_TEST_SUITES');
  if (files.length > MAX_SUITES) fail('TOO_MANY_TEST_SUITES');
  return { root, files: files.sort() };
}

export function buildInvocation(selection, executable = process.execPath) {
  // The explicit separator and separate argv elements avoid shell expansion.
  const args = ['--experimental-strip-types', '--test', '--test-reporter=tap',
    '--test-concurrency=1', '--test-timeout=300000', '--', ...selection.files];
  const length = [executable, ...args].reduce((total, value) => total + value.length * 2 + 3, 0);
  if (length > MAX_ARGUMENT_CHARS) fail('TEST_COMMAND_TOO_LONG');
  return { executable, args, options: {
    cwd: selection.root,
    shell: false,
    windowsHide: true,
    detached: false,
    stdio: ['ignore', 'inherit', 'inherit'],
  } };
}

export async function main(args = process.argv.slice(2), options = {}) {
  const stdout = options.stdout ?? process.stdout;
  const stderr = options.stderr ?? process.stderr;
  try {
    if (args.length === 1 && args[0] === '--help') {
      stdout.write('Usage: node scripts/Run-NodeTestSuites.mjs [--list]\nRuns top-level tests/scripts/*.test.{mjs,cjs,js,ts,mts,cts}. No restore or install.\n');
      return 0;
    }
    if (args.length > 1 || (args.length === 1 && args[0] !== '--list')) fail('INVALID_ARGUMENTS');
    requireNode(options.nodeVersion ?? process.versions.node);
    const selection = discoverSuites(options.repositoryRoot ?? ROOT);
    if (args[0] === '--list') {
      stdout.write(JSON.stringify({ schemaVersion: 1, count: selection.files.length, files: selection.files }) + '\n');
      return 0;
    }
    const invocation = buildInvocation(selection);
    stdout.write(`NODE_TEST_FILES=${selection.files.length}\n`);
    // node:test sets this for a worker. This child is a new test runner, not
    // that worker; all other environment/policy settings are preserved.
    const environment = { ...process.env };
    delete environment.NODE_TEST_CONTEXT;
    const child = (options.spawnProcess ?? spawn)(invocation.executable, invocation.args,
      { ...invocation.options, env: environment });
    return await new Promise(resolve => {
      let settled = false;
      child.once('error', () => {
        if (settled) return;
        settled = true;
        stderr.write('NODE_TEST_RUNNER=ERROR code=RUNNER_START_FAILED\n');
        resolve(2);
      });
      child.once('close', (code, signal) => {
        if (settled) return;
        settled = true;
        if (signal) {
          stderr.write('NODE_TEST_RUNNER=ERROR code=RUNNER_INTERRUPTED\n');
          resolve(signal === 'SIGINT' ? 130 : signal === 'SIGTERM' ? 143 : 2);
        } else if (!Number.isInteger(code) || code < 0) {
          stderr.write('NODE_TEST_RUNNER=ERROR code=RUNNER_EXIT_UNKNOWN\n');
          resolve(2);
        } else {
          stdout.write(`NODE_TEST_RUNNER_EXIT=${code}\n`);
          resolve(code);
        }
      });
    });
  } catch (error) {
    stderr.write(`NODE_TEST_RUNNER=ERROR code=${error instanceof TestSuiteError ? error.code : 'TEST_DISCOVERY_FAILED'}\n`);
    return 2;
  }
}

if (process.argv[1]) {
  let direct = false;
  try { direct = realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { /* Imported module. */ }
  if (direct) process.exitCode = await main();
}
