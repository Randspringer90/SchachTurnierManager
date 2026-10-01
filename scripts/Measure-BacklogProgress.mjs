import { openSync, readSync, closeSync, fstatSync, statSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { BacklogFormatError, MAX_BACKLOG_BYTES, measureBacklog } from './lib/BacklogProgress.mjs';

export function main(args, output = process.stdout, error = process.stderr) {
  try {
    let path = fileURLToPath(new URL('../docs/planning/BACKLOG.md', import.meta.url));
    let release = null; let explicitPath = false;
    for (let i = 0; i < args.length; i++) {
      if (args[i] === '--release' && release === null && args[i + 1] && !args[i + 1].startsWith('-')) release = args[++i];
      else if (!args[i].startsWith('-') && !explicitPath) { path = args[i]; explicitPath = true; }
      else throw new BacklogFormatError('INVALID_ARGUMENTS');
    }
    let bytes;
    // Reject known non-file inputs before open; opening a FIFO can block.
    if (!statSync(path).isFile()) throw new BacklogFormatError('NOT_A_REGULAR_FILE');
    const file = openSync(path, 'r');
    try {
      const stat = fstatSync(file);
      if (!stat.isFile()) throw new BacklogFormatError('NOT_A_REGULAR_FILE');
      if (stat.size > MAX_BACKLOG_BYTES) throw new BacklogFormatError('INPUT_TOO_LARGE');
      const buffer = Buffer.alloc(MAX_BACKLOG_BYTES + 1); let length = 0;
      while (length < buffer.length) {
        const read = readSync(file, buffer, length, buffer.length - length, null);
        if (read === 0) break;
        length += read;
      }
      if (length > MAX_BACKLOG_BYTES) throw new BacklogFormatError('INPUT_TOO_LARGE');
      bytes = buffer.subarray(0, length);
    } finally { closeSync(file); }
    // Retain a BOM in the string so sourceSha256 identifies the exact input bytes.
    const text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes);
    output.write(JSON.stringify(measureBacklog(text, release), null, 2) + '\n');
    return 0;
  } catch (failure) {
    const code = failure instanceof BacklogFormatError ? failure.code : 'INPUT_UNREADABLE';
    error.write(JSON.stringify({ status: 'ERROR', code }) + '\n');
    return 2;
  }
}

// Resolve symbolic/junction entry paths; never silently skip a real CLI call.
if (process.argv[1]) {
  let isMain = false;
  try { isMain = realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { /* Imported module. */ }
  if (isMain) process.exitCode = main(process.argv.slice(2));
}
