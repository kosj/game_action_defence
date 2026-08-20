// 웹 빌드를 실제 브라우저에서 돌리고 Godot 의 print() 출력을 콘솔에서 받아 적는다.
// Godot Web 은 print() 를 console.log 로 흘리므로 이것이 가장 깨끗한 데이터 경로다.
// playwright 는 로컬 설치일 수도, 전역 설치일 수도 있다. ESM 은 NODE_PATH 를 보지 않으므로
// 로컬 해석이 실패하면 전역 경로에서 직접 해석해 동적으로 불러온다.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
const req = createRequire(import.meta.url);
async function loadPlaywright() {
  try {
    return await import('playwright');
  } catch {
    const globals = (process.env.NODE_PATH || '/opt/node22/lib/node_modules').split(':');
    const resolved = req.resolve('playwright', { paths: globals });
    return await import(pathToFileURL(resolved).href);
  }
}
// CJS 진입점으로 해석되면 named export 가 안 잡히고 default 아래로 들어간다 — 둘 다 본다.
const pw = await loadPlaywright();
const chromium = pw.chromium ?? pw.default?.chromium;
if (!chromium) throw new Error('playwright 를 찾지 못했다 — npm i -D playwright 또는 NODE_PATH 확인');

const url = process.argv[2];
const budgetMs = parseInt(process.argv[3] || '240000', 10);

const browser = await chromium.launch({
  args: [
    '--enable-unsafe-swiftshader',   // GPU 가 없으므로 소프트웨어 GL 로 WebGL2 를 연다
    '--use-gl=angle', '--use-angle=swiftshader',
    '--no-sandbox', '--disable-dev-shm-usage',
  ],
});
const page = await browser.newPage({ viewport: { width: 720, height: 1280 } });

let done = false;
page.on('console', (m) => {
  const t = m.text();
  // 사용자 제스처가 없어 매 프레임 나오는 브라우저 경고는 버린다(수백 줄이 된다).
  if (t.includes('AudioContext was not allowed')) return;
  console.log(t);
  if (t.startsWith('BENCH ') || t.includes('핫패스 스크립트가 죽어')) done = true;
});
page.on('pageerror', (e) => console.log('[pageerror] ' + e.message));

await page.goto(url, { waitUntil: 'domcontentloaded' });

const t0 = Date.now();
while (!done && Date.now() - t0 < budgetMs) await page.waitForTimeout(1000);
console.log(done ? '[drive] 벤치 종료' : '[drive] 시간 초과 — 벤치가 끝나지 않았다');
await browser.close();
