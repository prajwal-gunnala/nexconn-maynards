// Loads the repo-root .env into process.env (existing env vars win). Never prints values.
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

export const SERVER_DIR = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
export const REPO_ROOT = path.resolve(SERVER_DIR, '..');

export function loadEnv(file = path.join(REPO_ROOT, '.env')) {
  let text;
  try { text = fs.readFileSync(file, 'utf8'); } catch { return false; }
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const m = line.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!m) continue;
    let v = m[2];
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    if (process.env[m[1]] === undefined) process.env[m[1]] = v;
  }
  return true;
}

export function config() {
  return {
    port: Number(process.env.PORT || 8787),
    appKey: process.env.NEXCONN_APP_KEY || '',
    appSecret: process.env.NEXCONN_APP_SECRET || '',
    nexconnDisabled: process.env.NEXCONN_DISABLED === '1',
    dataFile: process.env.JUGAAD_DB || path.join(SERVER_DIR, 'data', 'db.json'),
  };
}
