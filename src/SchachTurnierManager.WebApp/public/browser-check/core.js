/** Feature detection only. No permission requests, storage, network or device identity. */
const inspectFunction = read => {
  try { return typeof read() === 'function' ? 'available' : 'missing'; }
  catch { return 'unknown'; }
};
const inspectBoolean = read => {
  try { const value = read(); return value === true ? 'available' : value === false ? 'missing' : 'unknown'; }
  catch { return 'unknown'; }
};

export function inspectBrowser(environment) {
  const checks = {
    secureContext: inspectBoolean(() => environment?.isSecureContext),
    fileObjects: inspectFunction(() => environment?.File),
    arrayBuffer: inspectFunction(() => environment?.Blob?.prototype?.arrayBuffer),
    fileStream: inspectFunction(() => environment?.Blob?.prototype?.stream),
    textEncoder: inspectFunction(() => environment?.TextEncoder),
    textDecoder: inspectFunction(() => environment?.TextDecoder),
    readableStream: inspectFunction(() => environment?.ReadableStream),
    abortController: inspectFunction(() => environment?.AbortController),
    sha256Interface: inspectFunction(() => environment?.crypto?.subtle?.digest),
    serviceWorkerInterface: inspectFunction(() => environment?.navigator?.serviceWorker?.register),
  };
  function prerequisites(ids) {
    const values = ids.map(id => checks[id]);
    return values.includes('missing') ? 'missing' : values.includes('unknown') ? 'unknown' : 'available';
  }
  return {
    schemaVersion: 1,
    checks,
    features: {
      localBackupTools: prerequisites(['fileObjects', 'arrayBuffer', 'textDecoder']),
      backupChecksum: prerequisites(['fileObjects', 'arrayBuffer', 'secureContext', 'sha256Interface']),
      streamingRatingSearch: prerequisites(['fileObjects', 'fileStream', 'textDecoder', 'readableStream', 'abortController']),
      serviceWorkerPrerequisites: prerequisites(['secureContext', 'serviceWorkerInterface']),
    },
    executionVerified: false,
  };
}
