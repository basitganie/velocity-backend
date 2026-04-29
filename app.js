const express  = require('express');
const { spawnSync } = require('child_process');
const fs   = require('fs');
const path = require('path');
const os   = require('os');

const app = express();
app.use(express.json({ limit: '1mb' }));

// ── CORS ──────────────────────────────────────────────────────────────────
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// ── CONFIG — edit these paths ─────────────────────────────────────────────
const VELOCITY_BIN    = './velocity';
const VELOCITY_STDLIB = './stdlib';
const COMPILE_TIMEOUT = 12000;   // ms
const RUN_TIMEOUT     = 8000;    // ms

// ── HEALTH ────────────────────────────────────────────────────────────────
app.get('/', (_req, res) => res.json({ ok: true, service: 'velocity-backend' }));

// ── COMPILE + RUN ─────────────────────────────────────────────────────────
app.post('/compile', (req, res) => {
  const code  = req.body.code  || '';
  const flags = req.body.flags || '';          // string, e.g. "-v"
  const args  = req.body.args  || '';          // string, e.g. "arg1 arg2"
  const stdin = req.body.stdin || [];          // string[]

  if (!code.trim()) {
    return res.json({ stdout:'', stderr:'No code.', compileLog:'', exit:1 });
  }

  // ── 1. Temp workspace ──────────────────────────────────────────────────
  const tmp    = fs.mkdtempSync(path.join(os.tmpdir(), 'vel-'));
  const src    = path.join(tmp, 'main.vel');
  const outBin = path.join(tmp, 'out');

  fs.writeFileSync(src, code, 'utf8');

  // ── 2. Build compiler argv ─────────────────────────────────────────────
  // Base: velocity main.vel -o out
  // Extra flags from IDE (e.g. -v) inserted before source file
  const extraFlags = flags.trim() ? flags.trim().split(/\s+/) : [];
  const compilerArgv = [...extraFlags, src, '-o', outBin];

  // ── 3. Compile ─────────────────────────────────────────────────────────
  const compile = spawnSync(VELOCITY_BIN, compilerArgv, {
    timeout: COMPILE_TIMEOUT,
    env: { ...process.env, VELOCITY_STDLIB },
    cwd: tmp,
  });

  const compileLog = [compile.stdout, compile.stderr]
    .map(b => b?.toString() || '').join('').trim();

  if (compile.status !== 0 || compile.error) {
    cleanup(tmp);
    return res.json({
      stdout:     '',
      stderr:     compile.error?.message || compile.stderr?.toString() || 'Compilation failed.',
      compileLog,
      exit:       compile.status ?? 1,
      stage:      'compile',
    });
  }

  // ── 4. Build runtime argv ──────────────────────────────────────────────
  const runtimeArgv = args.trim() ? args.trim().split(/\s+/) : [];

  // ── 5. Run ─────────────────────────────────────────────────────────────
  const stdinText = stdin.join('\n') + (stdin.length ? '\n' : '');

  const run = spawnSync(outBin, runtimeArgv, {
    input:   stdinText,
    timeout: RUN_TIMEOUT,
    env:     {},          // clean env for user program
    cwd:     tmp,
  });

  cleanup(tmp);

  const runStdout = run.stdout?.toString() || '';
  const runStderr = run.stderr?.toString() || '';
  const runErr    = run.error ? `\nProcess error: ${run.error.message}` : '';

  res.json({
    stdout:     runStdout,
    stderr:     runStderr + runErr,
    compileLog,           // compile log separate — IDE shows this in compile tab only
    exit:       run.status ?? 0,
    stage:      'run',
  });
});

// ── CLEANUP ───────────────────────────────────────────────────────────────
function cleanup(dir) {
  try { fs.rmSync(dir, { recursive:true, force:true }); } catch(_){}
}

// ── START ─────────────────────────────────────────────────────────────────
const PORT = 8080;
app.listen(PORT, () => {
  console.log(`\n  Velocity backend  →  http://localhost:${PORT}`);
  console.log(`  Compiler          →  ${VELOCITY_BIN}`);
  console.log(`  Stdlib            →  ${VELOCITY_STDLIB}`);
  console.log(`  Ctrl+C to stop\n`);
});


