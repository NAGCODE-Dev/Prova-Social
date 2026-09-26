import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { redact } from '../browser/harness-redaction.mjs';

export function decision(stages, required) {
  if (required.some(id => stages.find(s => s.id === id)?.result === 'FAIL')) return 'FAIL';
  if (required.some(id => stages.find(s => s.id === id)?.result !== 'PASS')) return 'BLOCKED';
  return 'PASS';
}
export class Runner {
  constructor(directory) { this.directory = directory; this.stages = []; this.cancelled = false; this.activeCancel = null; }
  cancel() { this.cancelled = true; this.activeCancel?.(); }
  async record(id, result, reason, durationMs = 0) {
    if (this.stages.some(s => s.id === id)) throw new Error(`Duplicate QA stage: ${id}`);
    this.stages.push({ id, result, reason, durationMs, at: new Date().toISOString() });
    await mkdir(this.directory, { recursive: true });
    await writeFile(join(this.directory, 'report.json'), JSON.stringify({
      at: new Date().toISOString(), result: 'INCOMPLETE', stages: this.stages,
    }, null, 2));
    console.log(`${result} ${id}: ${reason}`);
    return result === 'PASS';
  }
  async command(id, command, args, { cwd, env = process.env, timeoutMs = 300000, sensitive = false, blockedExitCodes = [], allowAfterCancel = false, killGraceMs = 5000 } = {}) {
    if (this.cancelled && !allowAfterCancel) {
      await this.record(id, 'BLOCKED', 'Run cancelled');
      return { ok: false, output: '', code: null };
    }
    const start = Date.now();
    const result = await new Promise(resolve => {
      let output = '', stdout = '', stderr = '', timedOut = false, error;
      const child = spawn(command, args, { cwd, env, stdio: ['ignore', 'pipe', 'pipe'], detached: process.platform !== 'win32' });
      const capture = bytes => { output = (output + bytes.toString()).slice(-2000000); };
      child.stdout.on('data', bytes => { stdout = (stdout + bytes).slice(-2000000); capture(bytes); });
      child.stderr.on('data', bytes => { stderr = (stderr + bytes).slice(-2000000); capture(bytes); });
      child.on('error', e => { error = e.code; });
      const kill = signal => {
        try { process.kill(-child.pid, signal); } catch { child.kill(signal); }
      };
      let hardKill;
      this.activeCancel = () => {
        kill('SIGTERM');
        hardKill ??= setTimeout(() => kill('SIGKILL'), killGraceMs);
      };
      const timer = setTimeout(() => { timedOut = true; this.activeCancel(); }, timeoutMs);
      child.on('close', code => { clearTimeout(timer); clearTimeout(hardKill); resolve({ code, error, timedOut, output, stdout, stderr }); });
    });
    this.activeCancel = null;
    const state = (this.cancelled && !allowAfterCancel) || result.error === 'ENOENT' || blockedExitCodes.includes(result.code) ? 'BLOCKED' :
      result.code === 0 && !result.timedOut && !result.error ? 'PASS' : 'FAIL';
    await mkdir(this.directory, { recursive: true });
    await writeFile(join(this.directory, `${id}.log`), sensitive
      ? `Raw output withheld: may contain ephemeral credentials. exit=${result.code}; error=${result.error ?? ''}\n`
      : redact(result.output, 2000000));
    await this.record(id, state, result.error ?? (result.timedOut ? 'timeout' : `exit=${result.code}`), Date.now() - start);
    return { ...result, ok: state === 'PASS' };
  }
  async finish(required, metadata = {}) {
    const result = decision(this.stages, required);
    await writeFile(join(this.directory, 'report.json'), JSON.stringify({
      at: new Date().toISOString(), ...metadata, result, required, stages: this.stages,
    }, null, 2));
    console.log(`QA result: ${result}`);
    return result === 'PASS' ? 0 : result === 'FAIL' ? 1 : 2;
  }
}
