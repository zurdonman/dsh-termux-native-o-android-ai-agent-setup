// Debug only (dsh-web-debug.sh loads this with NODE_OPTIONS=--require).
//
// dsh's turn failed with "rename is not defined". This defines a global `rename`
// that only exists in debug sessions. When dsh code calls `rename(...)` without
// importing it, the call lands here instead of failing: the caller's file and
// line are written to stderr (captured in terminal.txt), and the real
// fs.promises.rename runs. Paths are not logged.
if (typeof globalThis.rename === 'undefined') {
  const fsp = require('node:fs/promises');
  let count = 0;
  globalThis.rename = function rename(from, to) {
    count += 1;
    if (count <= 20) {
      const frames = String(new Error().stack || '').split('\n').slice(2, 6).map((l) => l.trim()).join(' <- ');
      process.stderr.write(`[dsh-debug] rename() called without an import: ${frames}\n`);
    }
    return fsp.rename(from, to);
  };
}
