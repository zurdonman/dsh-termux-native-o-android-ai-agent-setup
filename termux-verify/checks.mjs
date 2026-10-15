// Runs inside Termux on Android. Usage: node checks.mjs <path to dsh/package.json>
// Prints one line per check: "CHECK <name> PASS|FAIL <detail>".
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const dshPkg = process.argv[2];
const req = createRequire(dshPkg);

const report = (name, status, detail = '') =>
  console.log(`CHECK ${name} ${status} ${String(detail).split('\n')[0]}`);

async function check(name, fn) {
  try {
    const detail = await fn();
    report(name, 'PASS', detail ?? '');
  } catch (e) {
    report(name, 'FAIL', e && e.message ? e.message : String(e));
  }
}

await check('node-version', () => `${process.version} platform=${process.platform} arch=${process.arch}`);

await check('node-pty-spawn', () => new Promise((resolve, reject) => {
  const pty = req('node-pty');
  const sh = `${process.env.PREFIX}/bin/sh`;
  const p = pty.spawn(sh, ['-c', 'echo PTY_OK'], { cwd: process.env.HOME, env: process.env });
  let buf = '';
  const timer = setTimeout(() => reject(new Error(`timeout, output so far: ${buf}`)), 20000);
  p.onData((d) => { buf += d; });
  p.onExit(() => {
    clearTimeout(timer);
    buf.includes('PTY_OK') ? resolve('PTY_OK') : reject(new Error(`no PTY_OK, output: ${buf}`));
  });
}));

await check('koffi-libc-call', () => {
  const koffi = req('koffi');
  const libc = koffi.load(process.platform === 'android' ? 'libc.so' : 'libc.so.6');
  const strlen = libc.func('size_t strlen(const char *s)');
  const n = strlen('abcd');
  if (n !== 4) throw new Error(`strlen returned ${n}`);
  return 'strlen("abcd")=4';
});

await check('sharp-render', async () => {
  const sharp = req('sharp');
  const buf = await sharp({ create: { width: 4, height: 4, channels: 3, background: '#ff0000' } }).png().toBuffer();
  if (!buf.length) throw new Error('empty PNG');
  return `png_bytes=${buf.length}`;
});

// dsh's glob/grep tools use @vscode/ripgrep via @deepseek-ai/dsh-tool-fs-search.
let rgPath;
await check('ripgrep-resolve', async () => {
  const fsSearchPkg = req.resolve('@deepseek-ai/dsh-tool-fs-search/package.json');
  const fromFsSearch = createRequire(fsSearchPkg);
  const entry = fromFsSearch.resolve('@vscode/ripgrep');
  const mod = await import(pathToFileURL(entry).href);
  rgPath = mod.rgPath;
  return rgPath;
});

await check('ripgrep-run', () => {
  if (!rgPath) throw new Error('rgPath unavailable (see ripgrep-resolve)');
  const out = execFileSync(rgPath, ['--version']).toString().split('\n')[0];
  return out;
});
