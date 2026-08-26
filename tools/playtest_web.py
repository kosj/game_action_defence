#!/usr/bin/env python3
"""웹(WASM+WebGL) 빌드를 브라우저에서 실제로 띄워 보고 스크린샷을 남긴다.

왜 필요한가
-----------
네이티브 자동 플레이테스트(`tools/playtest.gd`)는 수치를 정확히 주지만 **웹 전용 문제**는
잡지 못한다 — WASM 로딩 실패, WebGL 컨텍스트 문제, 캔버스 크기 정책(`canvas_resize_policy`)
같은 것들이다. 실기기 제보가 웹 빌드에서 나왔으므로 그 경로를 실제로 밟아 볼 수단이 필요하다.

⚠️ **이 환경에는 GPU 가 없다**(SwiftShader). 그래서 여기서 나오는 fps·frame_ms 는
실기기 값이 아니다. 이 스크립트로 판단할 수 있는 것은 **동작하는가**이지 **얼마나 빠른가**가
아니다. 속도는 실기기 PERF HUD 로 본다.

⚠️ **한 판이 매우 느리다 — 메뉴 한 단계 넘어가는 데 10초 넘게 걸린다.** 그래서 인게임까지
들어가는 긴 클릭 사슬(타이틀 → 메뉴 → 캐릭터 → 아레나 → 인트로 → 일시정지 → CHEATS → 토글)은
한 번 돌리는 데 몇 분이 걸리고, 중간에 좌표가 하나만 어긋나도 그 시간을 통째로 버린다.
**긴 사슬을 검증 수단으로 삼지 말 것.** 이 하네스가 값을 하는 지점은 앞쪽이다 —
빌드가 브라우저에서 뜨는가 · 콘솔 오류가 있는가 · 캔버스 크기가 얼마인가.
인게임 UI 토글의 실제 동작은 **실기기에서 사람이 한 번 눌러 보는 것이 훨씬 싸다**
(HALF RES 웹 버그도 그렇게 잡혔다).

    python3 tools/playtest_web.py --build /tmp/webdiag --secs 175 --hold 1200 \
        --shots 90,120,150 --out /tmp/webshots

기본 클릭 순서(`MENU_CHAIN`)가 타이틀에서 실제 플레이까지 데려간다. 다른 화면을 보려면
`--clicks ""` 로 끄거나 직접 지정한다.

빌드 만들기
-----------
지금은 **배포 프리셋 자체가 치트를 열어 두고 있다**(P0-12, 측정 기간 한정)이라 그냥 export 하면
CHEATS/PERF HUD 가 들어 있다:

    godot --headless --path . --export-release "Web" /tmp/webdiag/index.html

P0-12 가 되돌려진 뒤(= `custom_features=""`)에 진단 빌드가 필요하면, **커밋된 프리셋은 건드리지
말고** 작업 복사본에만 넣는다 — `verify_cheat_gate.gd` 가 커밋된 파일을 검사한다:
    cp export_presets.cfg /tmp/ep.orig
    sed -i 's/^custom_features=""/custom_features="cheats"/' export_presets.cfg
    godot --headless --path . --export-release "Web" /tmp/webdiag/index.html
    cp /tmp/ep.orig export_presets.cfg     # 반드시 되돌린다(CI 게이트가 검사한다)
"""

from __future__ import annotations

import argparse
import functools
import http.server
import pathlib
import socketserver
import sys
import threading
import time

## 컨테이너에 미리 깔린 Chromium. 버전 폴더명이 바뀌므로 글롭으로 찾는다
## (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers · 재다운로드 금지 설정이라 이걸 써야 한다).
def _chromium() -> str:
    for pat in ("chromium-*/chrome-linux/chrome", "chromium/chrome-linux/chrome"):
        hits = sorted(pathlib.Path("/opt/pw-browsers").glob(pat))
        if hits:
            return str(hits[-1])
    return ""


## 타이틀에서 실제 플레이까지 가는 클릭 순서(비율 좌표). 실측으로 맞춘 값이다.
## 소프트웨어 WebGL 이라 화면 전환이 느려 시각에 여유를 크게 뒀다 — 실기기나 GPU 가 있는
## 환경에서는 더 당겨도 된다.
##   10s 타이틀 TAP TO START · 18s New Game · 30s 캐릭터(Veteran) · 45s 아레나(Suburb)
##   58s 인트로 Skip(우상단) · 72s BEGIN
MENU_CHAIN = "10:0.5,0.5;18:0.5,0.356;30:0.5,0.21;45:0.5,0.23;58:0.87,0.05;72:0.5,0.885"

## 게임에 들어간 **뒤**의 순서 — 일시정지 > CHEATS > AUTO-PLAY > Resume.
## 이게 없으면 아무도 조종하지 않아 플레이어가 20초 만에 죽고 **게임오버 화면을 측정하게 된다**
## (실제로 그랬다: 173초 실행의 끝 두 장이 GAME OVER 였다).
## 좌표는 일시정지 패널 기준이며, CHEATS 를 펼치면 그 아래로 버튼이 붙는다.
## ⚠️ 일시정지 패널은 **CHEATS 를 펼치기 전과 후의 좌표가 다르다.** 접혔을 때는 버튼이 3개뿐이라
## 패널이 짧고 세로 중앙에 오고, 펼치면 길어지면서 위로 올라간다. 접힌 기준으로 CHEATS 를 누른
## 뒤부터 펼친 기준 좌표를 쓴다(이걸 섞어 써서 한 번 헛클릭했다).
##   접힘: CHEATS 0.597
##   펼침: Resume 0.208 · CHEATS 0.316 · AUTO-PLAY 0.365 · PERF HUD 0.624 · HALF RES 0.753
AUTOPLAY_CHAIN = "86:0.958,0.037;98:0.5,0.597;110:0.5,0.365;122:0.5,0.208"


def serve(directory: str) -> tuple[int, socketserver.TCPServer]:
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
    # 스레드 미지원 빌드라 COOP/COEP 헤더는 필요 없다 — 평범한 정적 서버로 뜬다.
    httpd = socketserver.TCPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd.server_address[1], httpd


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="/tmp/webdiag", help="index.html 이 있는 폴더")
    ap.add_argument("--secs", type=float, default=40.0, help="띄운 뒤 지켜볼 시간")
    ap.add_argument("--out", default="/tmp/webshots", help="스크린샷 폴더")
    ap.add_argument("--shots", default="8,20,40", help="스크린샷 시각(초, 쉼표)")
    ap.add_argument("--clicks", default=MENU_CHAIN,
                    help="캔버스를 누를 시각과 위치: '초:x비율,y비율' 을 세미콜론으로 잇는다. "
                         "예: 8:0.5,0.5;12:0.5,0.8  (비율이라 캔버스 크기가 바뀌어도 그대로 쓴다)")
    ap.add_argument("--autoplay", action="store_true",
                    help="게임 진입 후 CHEATS > AUTO-PLAY 를 켜서 조종 AI 가 놀게 한다. "
                         "없으면 플레이어가 가만히 있다가 20초 만에 죽는다.")
    ap.add_argument("--hold", type=int, default=180,
                    help="누르고 있는 시간(ms). 소프트웨어 WebGL 에서는 한 프레임이 길어 "
                         "짧게 누르면 버튼이 안 눌린다.")
    ap.add_argument("--width", type=int, default=786)     # 제보 스크린샷의 캔버스 크기
    ap.add_argument("--height", type=int, default=1398)
    args = ap.parse_args()

    build = pathlib.Path(args.build)
    if not (build / "index.html").exists():
        print(f"[WEB] {build}/index.html 이 없습니다 — 먼저 export 하세요.", file=sys.stderr)
        return 2
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    from playwright.sync_api import sync_playwright

    port, httpd = serve(str(build))
    url = f"http://127.0.0.1:{port}/index.html"
    print(f"[WEB] serving {build} -> {url}")

    shots = sorted(float(s) for s in args.shots.split(",") if s.strip())
    clicks: list[tuple[float, float, float]] = []
    for part in args.clicks.split(";"):
        part = part.strip()
        if not part:
            continue
        when, _, pos = part.partition(":")
        xf, _, yf = pos.partition(",")
        clicks.append((float(when), float(xf), float(yf)))
    if args.autoplay:
        for part in AUTOPLAY_CHAIN.split(";"):
            when, _, pos = part.partition(":")
            xf, _, yf = pos.partition(",")
            clicks.append((float(when), float(xf), float(yf)))
    clicks.sort()
    errors: list[str] = []

    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            executable_path=_chromium(),
            args=[
                # GPU 가 없으므로 SwiftShader 로 WebGL 을 돌린다. 이게 없으면 컨텍스트
                # 생성이 실패해 "게임이 안 뜬다" 로 오인하게 된다.
                "--enable-unsafe-swiftshader",
                "--use-gl=angle",
                "--use-angle=swiftshader",
                "--disable-dev-shm-usage",
            ],
        )
        page = browser.new_page(viewport={"width": args.width, "height": args.height})
        page.on("console", lambda m: errors.append(f"console.{m.type}: {m.text}")
                if m.type in ("error", "warning") else None)
        page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))

        t0 = time.time()
        page.goto(url, wait_until="load", timeout=120_000)
        # 캔버스가 생기고 실제 크기를 가질 때까지 기다린다(WASM 초기화 완료 신호).
        page.wait_for_selector("canvas", timeout=120_000)
        page.wait_for_function(
            "() => { const c = document.querySelector('canvas');"
            " return c && c.width > 0 && c.height > 0; }", timeout=180_000)
        print(f"[WEB] 캔버스 준비됨 ({time.time() - t0:.1f}s)")

        hold_ms = args.hold

        def pump(until: float) -> None:
            """지정 시각까지 기다리면서, 도중에 예정된 클릭을 흘려보낸다."""
            while time.time() - t0 < until:
                if clicks and time.time() - t0 >= clicks[0][0]:
                    _, xf, yf = clicks.pop(0)
                    box = page.locator("canvas").bounding_box()
                    x = box["x"] + box["width"] * xf
                    y = box["y"] + box["height"] * yf
                    # Godot 웹은 press 와 release 사이에 **프레임이 지나야** 버튼이 눌린다.
                    # Playwright 의 click() 은 down/up 이 한 틱 안에 붙어 호버만 되고 만다
                    # (실제로 New Game 이 하이라이트만 되고 안 눌렸다).
                    page.mouse.move(x, y)
                    page.wait_for_timeout(120)
                    page.mouse.down()
                    page.wait_for_timeout(hold_ms)
                    page.mouse.up()
                    print(f"[WEB] t={time.time() - t0:5.1f}s  클릭 ({xf:.2f}, {yf:.2f})")
                page.wait_for_timeout(150)

        for s in shots:
            pump(s)
            path = out / f"web_t{int(s):03d}.png"
            page.screenshot(path=str(path))
            # 백버퍼(c.width)와 **화면에 보이는 CSS 크기**를 따로 찍는다.
            # HALF RES 의 정의가 곧 이 둘의 분리다 — 백버퍼만 절반이 되고 CSS 는 그대로여야
            # 한다. 하나만 찍으면 "토글이 먹었는지" 와 "화면이 깨졌는지" 를 구분할 수 없다
            # (실제로 웹에서 둘 다 줄어들어 화면이 구석으로 처박혔다).
            size = page.evaluate(
                "() => { const c = document.querySelector('canvas');"
                " const r = c.getBoundingClientRect();"
                " return [c.width, c.height, Math.round(r.width), Math.round(r.height)]; }")
            print(f"[WEB] t={s:5.1f}s  백버퍼={size[0]}x{size[1]}  화면={size[2]}x{size[3]}"
                  f"  -> {path}")

        pump(args.secs)
        browser.close()
    httpd.shutdown()

    if errors:
        print(f"[WEB] 브라우저 로그 {len(errors)}건(앞 15건):")
        for e in errors[:15]:
            print("   ", e[:200])
    else:
        print("[WEB] 브라우저 오류 없음")
    return 0


if __name__ == "__main__":
    sys.exit(main())
