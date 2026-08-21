// wasm 힙 크기를 실제 브라우저에서 직접 관측한다 (P0-5).
//
// 왜 이게 필요한가
// ----------------
// 배포 웹 빌드가 wasm 힙 2GB 상한을 쳐서 죽었다. 그런데 게임 안에서는 그 값을 못 본다 —
// P0-10 에서 후보를 전부 재 보고 "잴 방법이 없다"고 적었다:
//   · Performance.MEMORY_STATIC → 웹에서 항상 0
//   · performance.memory.usedJSHeapSize → JS 힙만 본다(wasm 200MB 를 잡아도 안 움직인다)
//   · performance.measureUserAgentSpecificMemory → crossOriginIsolated 가 false 라 없다
//   · wasmMemory · Module · HEAP8 → Godot 4.3 웹 셸이 전역에 노출하지 않는다
//
// ⚠️ **그 결론은 "게임 안에서는" 만 맞다.** 테스트 드라이버는 페이지 밖에 있으므로,
// 페이지 스크립트보다 **먼저** `WebAssembly.Memory` 와 `instantiate`/`instantiateStreaming` 을
// 감싸 메모리 객체를 붙잡을 수 있다. 그러면 `buffer.byteLength` 가 곧 wasm 힙 크기다.
// 즉 **계측용으로는 잴 수 있다.** (배포 빌드에서 텔레메트리로 남기는 것은 여전히 불가능하다 —
// 후킹은 페이지를 우리가 만들 때만 가능하다.)
//
//   node tools/heap_web_driver.mjs <url> <실행시간ms>
//
// ⚠️ 이 환경에는 GPU 가 없어 SwiftShader 로 돈다. 게임이 **실시간의 약 1/9 로 기어간다** —
// 게임 시간 기준으로 환산해서 읽을 것. 힙 증가율은 벽시계가 아니라 게임 시간당으로 봐야 한다.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
const req = createRequire(import.meta.url);
async function loadPlaywright() {
  try { return await import('playwright'); }
  catch {
    const globals = (process.env.NODE_PATH || '/opt/node22/lib/node_modules').split(':');
    return await import(pathToFileURL(req.resolve('playwright', { paths: globals })).href);
  }
}
const pw = await loadPlaywright();
const chromium = pw.chromium ?? pw.default?.chromium;

const url = process.argv[2];
const runMs = parseInt(process.argv[3] || '300000', 10);

const browser = await chromium.launch({
  args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader',
         '--no-sandbox', '--disable-dev-shm-usage'],
});
const page = await browser.newPage({ viewport: { width: 720, height: 1280 } });

await page.addInitScript(() => {
  const OM = WebAssembly.Memory;
  WebAssembly.Memory = function (d) { const m = new OM(d); globalThis.__wm = m; return m; };
  WebAssembly.Memory.prototype = OM.prototype;
  const grab = (r) => {
    try {
      const inst = r && r.instance ? r.instance : r;
      if (inst && inst.exports && inst.exports.memory) globalThis.__wm = inst.exports.memory;
    } catch (e) {}
    return r;
  };
  for (const k of ['instantiate', 'instantiateStreaming']) {
    const o = WebAssembly[k];
    if (o) WebAssembly[k] = (...a) => o(...a).then(grab);
  }
});

page.on('console', (m) => {
  const t = m.text();
  if (t.includes('AudioContext was not allowed')) return;
  if (t.startsWith('HEAP ') || t.includes('Cannot enlarge') || t.includes('Aborted') || t.includes('USER ERROR')) console.log(t);
});
page.on('pageerror', (e) => console.log('[pageerror] ' + e.message));

await page.goto(url, { waitUntil: 'domcontentloaded' });

const t0 = Date.now();
let first = null;
while (Date.now() - t0 < runMs) {
  await page.waitForTimeout(30000);
  const bytes = await page.evaluate(() => (globalThis.__wm ? globalThis.__wm.buffer.byteLength : -1))
    .catch((e) => { console.log('[eval err] ' + e.message.split('\n')[0]); return -2; });
  const mb = bytes / 1048576;
  if (first === null && bytes > 0) first = mb;
  const el = (Date.now() - t0) / 1000;
  const rate = first !== null && el > 0 ? ((mb - first) / (el / 60)) : 0;
  console.log(`[WASM] t=${el.toFixed(0)}s heap=${bytes > 0 ? mb.toFixed(1) + 'MB' : bytes} 증가율=${rate.toFixed(2)}MB/분`);
}
await browser.close();
