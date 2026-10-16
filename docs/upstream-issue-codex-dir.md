# Issue for songoao25/dsh-chatgpt-sub (draft)

Use this text to open a **Bug report** at https://github.com/songoao25/dsh-chatgpt-sub/issues/new?template=bug_report.yml
Title: `[Bug]: Sign-in succeeds in browser but is not saved when ~/.codex does not exist`

## Problem description

After completing the ChatGPT browser sign-in, the plugin reports
`oauth.write-failed` ("Signed in, but it could not be saved locally") and
unbinds. The user has to sign in again, and this repeats every time.

Root cause: `writeAuthJson()` in `src/host.js` (line ~258) writes
`<CODEX_AUTH_FILE>.tmp` and renames it to `auth.json`, but it never creates the
parent directory. `writeBindFlag()` (line ~166) does call `mkdirSync(dirname(...), { recursive: true })`,
so only the auth write is affected. If `~/.codex` does not exist, `writeFileSync` throws
`ENOENT`. The catch around the call at line ~953 turns that into `oauth.write-failed` (line ~955),
and the flow rolls back.

`~/.codex` is normally created by the Codex CLI, so users who never ran `codex` hit this.

## Steps to reproduce

1. Make sure `~/.codex` does not exist (`rm -rf ~/.codex`).
2. Start DSH with the plugin installed.
3. Plugins → ChatGPT Subscription → "Sign in with ChatGPT". Complete the login in the browser.
4. The browser shows the success page, but the plugin shows "Aún no has iniciado sesión" / sign-in required.
5. `GET /_dsh/dsh-chatgpt-sub/getCodexBridgeStatus` returns
   `{"ok":false,"bound":false,"oauthInFlight":false,"error":{"kind":"write","code":"oauth.write-failed"}}`.

Node reproduction, independent of DSH:

```js
const { writeFileSync, renameSync } = require('fs');
const p = process.env.HOME + '/.codex/auth.json';
writeFileSync(p + '.tmp', '{}', { mode: 0o600 }); // throws ENOENT
```

## Expected behavior

The auth file is written and the plugin shows "Connected". `writeAuthJson()` should create the parent
directory with `mkdirSync(dirname(filePath), { recursive: true, mode: 0o700 })`, as `writeBindFlag()` already does.

Suggested fix (one line, before `writeFileSync(tmp, ...)` in `writeAuthJson`):

```js
mkdirSync(dirname(filePath), { recursive: true, mode: 0o700 })
```

## Environment

- DSH: `@deepseek-ai/dsh` 0.2.0-rc.2 (plugin source at commit `c8057f5`, npm 0.6.1)
- Device: Android 15 (arm64), running DSH inside Termux (Node v26.4.0)
- Home directory: Termux home; `~/.codex` absent
- Workaround that works for us: `mkdir -p ~/.codex && chmod 700 ~/.codex`, then sign in again.
