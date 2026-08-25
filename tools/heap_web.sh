#!/usr/bin/env bash
# 웹 빌드를 export → 로컬 서버 → Chromium 으로 띄우고 **wasm 힙 크기를 직접 관측**한다 (P0-5).
#
#   tools/heap_web.sh "min=0 every=30" 660000
#         └ 게임 스크립트 인자              └ 실행 시간(ms)
#
# ⚠️ 릴리스로 내보내되 이 측정 동안만 custom_features 에 cheats 를 넣는다(bench_web.sh 와 같은 이유).
#    끝나면 바로 되돌린다 — 레포에 남기면 안 되는 설정이다.
set -euo pipefail
cd /home/user/game_action_defence
GODOT="${GODOT:-godot}"; PORT=8801; OUT=build/webheap
ARGS="${1:-min=0}"; RUNMS="${2:-300000}"
cp export_presets.cfg /tmp/ep2.bak
trap 'cp /tmp/ep2.bak export_presets.cfg; kill ${SRV:-0} 2>/dev/null || true' EXIT
sed -i 's/^custom_features=""/custom_features="cheats"/' export_presets.cfg
mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html" >/dev/null 2>&1
cp /tmp/ep2.bak export_presets.cfg
python3 - "$OUT" "$ARGS" <<'PY'
import io, json, sys
out, args = sys.argv[1], sys.argv[2].split()
s = io.open(out + "/index.html", encoding="utf-8").read()
s = s.replace('"args":[]', '"args":' + json.dumps(["--script", "res://tools/heap_hunt.gd", "--"] + args), 1)
io.open(out + "/index.heap.html", "w", encoding="utf-8").write(s)
PY
npx --yes http-server "$OUT" -p "$PORT" --silent >/dev/null 2>&1 &
SRV=$!
for _ in $(seq 1 40); do curl -fsS -o /dev/null "http://127.0.0.1:$PORT/index.heap.html" 2>/dev/null && break; sleep 0.5; done
NODE_PATH="${NODE_PATH:-/opt/node22/lib/node_modules}" node tools/heap_web_driver.mjs "http://127.0.0.1:$PORT/index.heap.html" "$RUNMS"
