// 웹 빌드의 **실제 오디오 출력을 캡처해** 품질을 수치로 잰다.
//
// 왜 필요한가
// -----------
// P0-5 에서 웹 재생 방식을 SAMPLE → STREAM 으로 바꿔 힙 누수를 막았다. 그런데 STREAM 은
// wasm 안 소프트웨어 믹서를 타므로 **버퍼 언더런(끊김·지직거림)** 이 날 수 있다.
// "느낌"으로 판단하지 않으려고, WebAudio 그래프에 탭을 걸어 PCM 을 직접 받아 잰다.
//
// 어떻게 잡나 — Godot 웹 셸은 AudioContext 를 자기 안에서 만들고 destination 에 연결한다.
// 그래서 페이지 스크립트보다 먼저 ① AudioContext 생성자와 ② AudioNode.connect 를 감싸,
// destination 으로 가는 모든 연결을 ScriptProcessor 로도 갈라 받는다.
//
// 무엇을 재나
//   · 블록 RMS 곡선          — 소리가 나야 할 구간에 무음이 끼면 끊김이다
//   · 불연속(클릭) 개수       — 인접 샘플이 크게 튀면 그것이 지직거림의 실체다
//   · 무음 구간(드롭아웃) 개수 — 소리 도중 연속 무음 블록
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
const req = createRequire(import.meta.url);
async function loadPlaywright() {
  try { return await import('playwright'); }
  catch {
    const g = (process.env.NODE_PATH || '/opt/node22/lib/node_modules').split(':');
    return await import(pathToFileURL(req.resolve('playwright', { paths: g })).href);
  }
}
const pw = await loadPlaywright();
const chromium = pw.chromium ?? pw.default?.chromium;

const url = process.argv[2];
const warmMs = parseInt(process.argv[3] || '20000', 10);
const recMs = parseInt(process.argv[4] || '15000', 10);
const label = process.argv[5] || '';

const browser = await chromium.launch({
  args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader',
         '--no-sandbox', '--disable-dev-shm-usage',
         // 오디오가 실제로 돌아야 잴 수 있다.
         '--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage({ viewport: { width: 720, height: 1280 } });

await page.addInitScript(() => {
  globalThis.__cap = [];
  globalThis.__rec = false;
  const OrigAC = window.AudioContext || window.webkitAudioContext;
  const wrap = function (...a) {
    const ctx = new OrigAC(...a);
    globalThis.__ctx = ctx;
    globalThis.__rate = ctx.sampleRate;
    try {
      const sp = ctx.createScriptProcessor(4096, 2, 2);
      sp.onaudioprocess = (e) => {
        if (!globalThis.__rec) return;
        globalThis.__cap.push(Float32Array.from(e.inputBuffer.getChannelData(0)));
      };
      // 탭은 출력에 소리를 더하지 않게 게인 0 으로 destination 에 붙인다
      // (ScriptProcessor 는 연결돼 있어야 onaudioprocess 가 돈다).
      const g = ctx.createGain(); g.gain.value = 0;
      sp.connect(g); g.connect(ctx.destination);
      globalThis.__tap = sp;
    } catch (e) { globalThis.__taperr = String(e); }
    return ctx;
  };
  wrap.prototype = OrigAC.prototype;
  window.AudioContext = wrap;
  if (window.webkitAudioContext) window.webkitAudioContext = wrap;

  const oc = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (dest, ...r) {
    try {
      if (globalThis.__tap && globalThis.__ctx && dest === globalThis.__ctx.destination
          && this !== globalThis.__tap) {
        oc.call(this, globalThis.__tap);
      }
    } catch (e) {}
    return oc.call(this, dest, ...r);
  };
});

page.on('pageerror', (e) => console.log('[pageerror] ' + e.message));
await page.goto(url, { waitUntil: 'domcontentloaded' });
await page.waitForTimeout(warmMs);
await page.evaluate(() => { globalThis.__cap = []; globalThis.__rec = true; });
await page.waitForTimeout(recMs);

const r = await page.evaluate(() => {
  globalThis.__rec = false;
  const chunks = globalThis.__cap;
  if (!chunks.length) return { err: 'PCM 을 한 조각도 못 받았다 (탭 실패: ' + (globalThis.__taperr || '연결 없음') + ')' };
  let n = 0; for (const c of chunks) n += c.length;
  const x = new Float32Array(n); let o = 0;
  for (const c of chunks) { x.set(c, o); o += c.length; }

  const B = 1024;
  const rms = [];
  for (let i = 0; i + B <= x.length; i += B) {
    let s = 0; for (let j = 0; j < B; j++) s += x[i + j] * x[i + j];
    rms.push(Math.sqrt(s / B));
  }
  const peak = Math.max(...rms);
  const loud = rms.filter((v) => v > peak * 0.05).length;
  // 드롭아웃 — 소리 나는 구간(첫 유성 블록 ~ 마지막 유성 블록) 안의 무음 블록
  let first = rms.findIndex((v) => v > peak * 0.05);
  let last = rms.length - 1 - [...rms].reverse().findIndex((v) => v > peak * 0.05);
  let gaps = 0, run = 0, maxRun = 0;
  for (let i = first; i <= last && first >= 0; i++) {
    if (rms[i] <= peak * 0.01) { run++; maxRun = Math.max(maxRun, run); }
    else { if (run >= 2) gaps++; run = 0; }
  }
  // 클릭 — 인접 샘플 도약. 정상 파형은 44.1kHz 에서 이렇게 튀지 않는다.
  let clicks = 0, maxJump = 0;
  for (let i = 1; i < x.length; i++) {
    const d = Math.abs(x[i] - x[i - 1]);
    if (d > maxJump) maxJump = d;
    if (d > 0.30) clicks++;
  }
  return {
    rate: globalThis.__rate, samples: x.length,
    seconds: +(x.length / globalThis.__rate).toFixed(2),
    peakRms: +peak.toFixed(4),
    loudBlocks: loud, totalBlocks: rms.length,
    dropouts: gaps, maxSilentBlocks: maxRun,
    clicks, maxJump: +maxJump.toFixed(3),
  };
});
console.log('[AUDIO' + (label ? ' ' + label : '') + '] ' + JSON.stringify(r));
await browser.close();
