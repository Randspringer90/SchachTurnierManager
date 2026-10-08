import {createHash} from 'node:crypto';
import {lstatSync, readdirSync, readFileSync, writeFileSync} from 'node:fs';
import {join, relative, resolve} from 'node:path';

const STAMP = /^\/\/ STM shell build fingerprint: [a-f0-9]{64}\r?\n/;
const MAX_FILE_BYTES = 16 * 1024 * 1024;
const MAX_TOTAL_BYTES = 64 * 1024 * 1024;
function resourceName(name) {
  if (typeof name !== 'string' || !/^[a-zA-Z0-9_.-]+(?:\/[a-zA-Z0-9_.-]+)*$/.test(name)
      || name.split('/').some(part => part === '.' || part === '..')) throw Error('Unsafe PWA build resource name.');
  return name;
}

// This changes the worker bytes whenever this build's HTML, bundles or public
// resources change. Browser update detection compares worker bytes, not index.html.
export function stampServiceWorker(worker, resources) {
  if (typeof worker !== 'string' || !worker.length) throw Error('Missing service worker source.');
  if (!Array.isArray(resources) || resources.length > 1024) throw Error('Invalid PWA build resource set.');
  const body = worker.replace(STAMP, '');
  const entries = new Map(), folded = new Set();
  let total = Buffer.byteLength(body);
  for (const [rawName, rawBytes] of resources) {
    const name = resourceName(rawName);
    if (name.toLowerCase() === 'service-worker.js' || folded.has(name.toLowerCase())) throw Error('Duplicate PWA build resource.');
    folded.add(name.toLowerCase());
    const bytes = Buffer.from(rawBytes);
    total += bytes.length;
    if (bytes.length > MAX_FILE_BYTES || total > MAX_TOTAL_BYTES) throw Error('PWA build resource limit exceeded.');
    entries.set(name, bytes);
  }
  if (!entries.has('index.html')) throw Error('Final PWA index.html is missing.');
  const hash = createHash('sha256').update('STM_PWA_SHELL_BUILD_V1\n').update(body);
  for (const name of [...entries.keys()].sort()) {
    const bytes = entries.get(name);
    hash.update(JSON.stringify([name, bytes.length])).update('\0').update(bytes).update('\0');
  }
  return `// STM shell build fingerprint: ${hash.digest('hex')}\n${body}`;
}

function publicNames(directory, prefix = '', result = []) {
  if (!lstatSync(directory).isDirectory() || lstatSync(directory).isSymbolicLink()) throw Error('Unsafe PWA public directory.');
  for (const entry of readdirSync(directory, {withFileTypes:true})) {
    const name = resourceName(prefix + entry.name), full = join(directory, entry.name);
    if (entry.isSymbolicLink()) throw Error('PWA public symlinks are forbidden.');
    if (entry.isDirectory()) publicNames(full, name + '/', result);
    else if (entry.isFile()) result.push(name);
    else throw Error('Unsafe PWA public entry.');
    if (result.length > 1024) throw Error('Too many PWA public files.');
  }
  return result;
}

export function serviceWorkerBuildFingerprint() {
  let config;
  return {
    name:'stm-service-worker-build-fingerprint', apply:'build', enforce:'post',
    configResolved(resolved) { config = resolved; },
    writeBundle: {
      order:'post',
      handler(options, bundle) {
        if (!config?.publicDir || !config.build.copyPublicDir || !options.dir) throw Error('PWA fingerprint needs copied public resources and a directory build.');
        const outDir = resolve(options.dir);
        if (outDir !== resolve(config.root, config.build.outDir) || lstatSync(outDir).isSymbolicLink()) throw Error('Unexpected PWA output directory.');
        const names = new Set([...publicNames(config.publicDir), ...Object.keys(bundle)]);
        const workerPath = join(outDir, 'service-worker.js');
        const resources = [];
        let totalBytes = 0;
        for (const rawName of [...names].sort()) {
          const name = resourceName(rawName);
          const path = join(outDir, name);
          // Check every component before reading a copied or generated build file.
          let cursor = outDir;
          for (const part of relative(outDir, path).split(/[\\/]/)) {
            cursor = join(cursor, part);
            if (lstatSync(cursor).isSymbolicLink()) throw Error('PWA output symlink is forbidden.');
          }
          const metadata = lstatSync(path);
          if (!metadata.isFile() || metadata.size > MAX_FILE_BYTES) throw Error('Invalid PWA output resource.');
          totalBytes += metadata.size;
          if (totalBytes > MAX_TOTAL_BYTES) throw Error('PWA output total limit exceeded.');
          if (name !== 'service-worker.js') resources.push([name, readFileSync(path)]);
        }
        const original = readFileSync(workerPath, 'utf8');
        writeFileSync(workerPath, stampServiceWorker(original, resources), 'utf8');
      }
    }
  };
}
