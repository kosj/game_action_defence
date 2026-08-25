#!/usr/bin/env bash
# 웹 빌드를 **실제 브라우저에서** 돌려 벤치 수치를 받아 온다.
#
# 왜 필요한가
# -----------
# 헤드리스 벤치는 x86-64 네이티브 GDScript 를 잰다. 실제로 배포되는 것은 **WASM** 이고,
# 그 배수는 지금까지 "웹은 데스크톱의 3~4배"라는 **추정치**로만 쓰여 왔다(P1-18). 그 추정을
# 세운 측정 자체가 깨져 있었으므로(OPTIMIZATION_PLAN.md §5-L) 가장 못 믿을 숫자였다.
# 이 스크립트가 그 자리를 실측으로 바꾼다.
#
# 무엇을 재고 무엇을 못 재나
# --------------------------
#   ✅ WASM 로직 비용(물리 틱) · 브라우저 이벤트 루프/GC 스파이크 · 드로우 콜 · pck 크기
#   ❌ 실제 GPU 시간 — 이 환경에는 GPU 가 없어 SwiftShader(소프트웨어 GL)로 돈다.
#      모바일 GPU 의 fill-rate 는 여전히 실기기에서만 나온다.
#   ❌ 폰 CPU 의 절대 속도 — 여기는 x86 이다. 나오는 것은 **배수**이지 폰의 fps 가 아니다.
#
# 사용법
#   tools/bench_web.sh                       # 최대 부하
#   tools/bench_web.sh "min=26 measure=20"   # 인자 직접 지정
#
# 필요한 것: godot(GODOT 환경변수) · export 템플릿 · node + playwright + http-server
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
ARGS="${1:-min=26 warm=6 measure=20 build=engineer_late stress=1}"
PORT="${PORT:-8765}"
OUT="build/web"

# ⚠️ 릴리스 빌드로 재야 한다 — 디버그 빌드는 검사 오버헤드로 비용을 부풀린다.
# 그런데 릴리스는 치트가 잠겨(Cheats.enabled) 시나리오를 못 만든다. 그래서 이 측정에서만
# `custom_features="cheats"` 로 내보내고 **바로 되돌린다**(레포에 남기면 안 되는 설정이다).
cp export_presets.cfg /tmp/export_presets.bench.bak
trap 'cp /tmp/export_presets.bench.bak export_presets.cfg' EXIT
sed -i 's/^custom_features=""/custom_features="cheats"/' export_presets.cfg
mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html" >/dev/null 2>&1
cp /tmp/export_presets.bench.bak export_presets.cfg

# Godot Web 은 커맨드라인을 index.html 의 GODOT_CONFIG.args 로 받는다.
# 배포본을 건드리지 않도록 벤치 전용 셸을 따로 만든다.
python3 - "$OUT" "$ARGS" <<'PY'
import io, json, sys
out, args = sys.argv[1], sys.argv[2].split()
s = io.open(out + "/index.html", encoding="utf-8").read()
inject = ["--script", "res://tools/bench_lategame.gd", "--"] + args
s = s.replace('"args":[]', '"args":' + json.dumps(inject), 1)
io.open(out + "/index.bench.html", "w", encoding="utf-8").write(s)
PY

# ⚠️ 경로를 먼저 준다 — `-p PORT -s PATH` 순서면 PATH 가 루트로 안 잡혀 전부 404 가 난다.
npx --yes http-server "$OUT" -p "$PORT" --silent >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true; cp /tmp/export_presets.bench.bak export_presets.cfg' EXIT
# 서버가 실제로 응답할 때까지 기다린다 — 고정 sleep 으로는 첫 실행에서 404 가 난다.
for _ in $(seq 1 40); do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/index.bench.html" 2>/dev/null; then break; fi
  sleep 0.5
done
curl -fsS -o /dev/null "http://127.0.0.1:$PORT/index.pck" || { echo "서버가 pck 를 못 준다 — 경로를 확인할 것"; exit 1; }
# playwright 가 전역 설치인 환경(이 컨테이너)에서도 import 가 풀리도록 NODE_PATH 를 준다.
NODE_PATH="${NODE_PATH:-/opt/node22/lib/node_modules}" node tools/bench_web_driver.mjs "http://127.0.0.1:$PORT/index.bench.html" "${TIMEOUT_MS:-420000}"
