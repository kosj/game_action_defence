# 플레이어 캐릭터 스프라이트 작업 인수인계

새 세션에서 이 문서만 읽고 이어서 작업할 수 있도록 정리한 문서입니다.
마지막 갱신: 베테랑 걷기 4프레임 적용(PR #249) 시점.

---

## 1. 지금 게임에 적용된 상태

| 캐릭터 | 걷기 시트 | 프레임 수 | 대기 이미지 | 비고 |
|---|---|---|---|---|
| veteran | `assets/sprites/run_veteran.png` (460×154) | **4** | `idle_veteran.png` | 최신 걷기 아트. 다만 4프레임의 포즈 차이가 작아 "잔걸음"으로 읽힘 |
| hunter | `assets/sprites/run_hunter.png` (1752×157) | 8 | `idle_hunter.png` | 구 키포즈(달리기) 아트 |
| engineer | `assets/sprites/run_engineer.png` (1232×162) | 8 | `idle_engineer.png` | 구 키포즈(달리기) 아트 |

- 프레임 수는 `data/character_db.tres` 의 `run_frames` 가 결정한다. veteran 만 `run_frames = 4`.
- 걷기 속도는 프레임 수와 무관하다 — `Player.gd` 의 `_RUN_CYCLE_PX = 80.0`, 한 사이클 = 80px 이동.
- 정지 시 `idle_<id>.png` 로 교체, 이동 시 시트로 복귀 (`Player.gd` `_animate_walk`).
- 파일만 교체하면 코드 수정 없이 반영된다. 프레임 수가 바뀌면 `run_frames` 만 고치면 된다.

---

## 2. 확정된 아트 디렉션

기존 좀비·보스 아트(`assets/sprites/zombie_*.png`, `boss_*.png`)와 통일하기 위해 아래로 확정했다.

- **북미 코믹 카툰** — 굵은 검정 외곽선, 채도 높고 약간 지저분한 포스트아포칼립스 팔레트
- **3톤 셀 셰이딩** — 베이스 + 그림자 + 밝은 하이라이트, 전부 하드 엣지 (그라데이션 금지)
- **청키 5등신** — 큰 머리, 두꺼운 팔다리, 오버사이즈 손·발
- **애니 일러스트 / 실사 렌더링 / 에어브러시 금지**
- **무기를 두 손으로 들고 전방(오른쪽) 조준** — 자동 발사 게임플레이와 일치
  - veteran: 어썰트 라이플 / hunter: 석궁 / **engineer: 네일건** (렌치 아님, 사용자 확정)
- 배경은 **단색 마젠타 `#FF00FF`**, 지면선·그림자·텍스트 없음
- 캐릭터 전체가 **끊기지 않는 굵은 검정 외곽선으로 완전히 둘러싸일 것** (키잉 품질에 직결)

### 캐릭터별 실루엣 특징
- **veteran**: 가장 넓은 어깨, 붉은 반다나에 뒤로 휘날리는 꼬리 두 가닥, 흰 수염, 올리브색 민소매 전술조끼 — 강조색 **빨강**
- **hunter**: 뾰족하게 솟은 초록 후드, 후드 밑으로 나온 검은 포니테일 하나, 삼각형 초록 망토 — 강조색 **초록**
- **engineer**: 둥근 돔형 노란 안전모(고글 얹힘), 통 넓은 갈색 멜빵바지, 오버사이즈 부츠 — 강조색 **노랑**

---

## 3. 남은 작업

1. 세 캐릭터의 **기준 이미지(대기, 무기 들고 전방 조준)** 생성 → 스타일 컨펌
2. 기준 이미지를 소스로 **걷기 4포즈** 생성 (상체·무기 고정, 다리만 변경)
3. 키잉 → 정렬 → 4프레임 시트 조립 → `run_frames = 4` → 인게임 검증 → 커밋/PR/스쿼시 머지

> **핵심 교훈**: 한 이미지 안에 여러 포즈를 요구하면 생성기가 첫 포즈를 복제한다(이 세션에서 6회 연속 재현). **한 이미지 = 한 포즈**로 따로 생성해야 한다. 무기를 두 손으로 들면 팔이 고정되므로 다리만 다르면 되고, 그만큼 성공률이 올라간다.
>
> **추가 교훈(측정 완료)**: 기준 이미지를 레퍼런스로 물리면 포즈가 바뀌지 않는다. 자세한 수치와
> 2단계 레시피는 아래 [4-5절](#4-5-생성-방식--측정으로-확인된-것-중요) 참고.

---

## 4. 프롬프트 (그대로 복사해 사용)

### 4-1. 기준 이미지 — 베테랑

```
ONE single figure only, centered, full body visible, on a flat solid magenta #FF00FF background filling the entire image.

A grizzled veteran commando standing ready, side view facing right, holding his weapon up and aimed forward.

ART STYLE: North American comic-book cartoon game art, like a western animated action cartoon. Bold thick black outlines around every shape. Cel shading with three flat steps per color: a base tone, one darker shadow tone, and one bright highlight - all hard-edged, no gradients. Saturated, slightly grimy post-apocalyptic palette. Chunky exaggerated cartoon proportions about 5 heads tall: big head, thick heavy limbs, oversized hands and boots. NO anime style, NO realistic rendering, NO soft airbrush. The entire figure must be fully enclosed by a continuous unbroken thick black outline so it separates cleanly from the magenta.

CHARACTER: broad shoulders, thick bare arms, a RED bandana with two long tails streaming backward, a big white beard, an olive-green sleeveless tactical vest, an ammo belt, dark trousers, chunky black boots.

WEAPON: he grips exactly ONE assault rifle in BOTH hands, held up at chest height and aimed forward to the right, ready to fire. No rifle on his back, no second weapon.

POSE: standing at rest but alert. Both boots flat on the ground, side by side, shoulder-width apart, legs straight.

Flat solid magenta #FF00FF background. No ground line, no shadow, no text.
```

### 4-2. 기준 이미지 — 헌터

```
ONE single figure only, centered, full body visible, on a flat solid magenta #FF00FF background filling the entire image.

A hooded huntress standing ready, side view facing right, holding her weapon up and aimed forward.

ART STYLE: North American comic-book cartoon game art, like a western animated action cartoon. Bold thick black outlines around every shape. Cel shading with three flat steps per color: a base tone, one darker shadow tone, and one bright highlight - all hard-edged, no gradients. Saturated, slightly grimy post-apocalyptic palette. Chunky exaggerated cartoon proportions about 5 heads tall: big head, thick heavy limbs, oversized hands and boots. NO anime style, NO realistic rendering, NO soft airbrush. The entire figure must be fully enclosed by a continuous unbroken thick black outline so it separates cleanly from the magenta.

CHARACTER: a forest-green hood with a sharp pointed peak jutting up and back above her head, ONE long black ponytail hanging out from under the hood behind her, a short green cape hanging as a clean triangle behind her, a dark leather bodice, dark trousers, tall chunky brown boots.

WEAPON: she grips exactly ONE crossbow in BOTH hands, held up at chest height and aimed forward to the right, ready to fire. No bow, no quiver, no second weapon.

POSE: standing at rest but alert. Both boots flat on the ground, side by side, shoulder-width apart, legs straight.

Flat solid magenta #FF00FF background. No ground line, no shadow, no text.
```

### 4-3. 기준 이미지 — 엔지니어

```
ONE single figure only, centered, full body visible, on a flat solid magenta #FF00FF background filling the entire image.

A young field engineer standing ready, side view facing right, holding his weapon up and aimed forward.

ART STYLE: North American comic-book cartoon game art, like a western animated action cartoon. Bold thick black outlines around every shape. Cel shading with three flat steps per color: a base tone, one darker shadow tone, and one bright highlight - all hard-edged, no gradients. Saturated, slightly grimy post-apocalyptic palette. Chunky exaggerated cartoon proportions about 5 heads tall: big head, thick heavy limbs, oversized hands and boots. NO anime style, NO realistic rendering, NO soft airbrush. The entire figure must be fully enclosed by a continuous unbroken thick black outline so it separates cleanly from the magenta.

CHARACTER: built from rounded chunky shapes, wide baggy legs, oversized brown work boots, a round dome-shaped YELLOW hard hat with a short brim and goggles resting on top, wide brown overalls with a chest bib and shoulder straps, rolled-up cream shirt sleeves.

WEAPON: he grips exactly ONE industrial nail gun in BOTH hands, held up at chest height and aimed forward to the right, ready to fire. No wrench, no backpack, no second weapon.

POSE: standing at rest but alert. Both boots flat on the ground, side by side, shoulder-width apart, legs straight.

Flat solid magenta #FF00FF background. No ground line, no shadow, no text.
```

### 4-4. 걷기 4포즈

기준 이미지 프롬프트에서 **마지막 `POSE:` 문단만** 아래로 교체해 4번 따로 생성한다.
나머지 문단(배경/스타일/캐릭터/무기)은 글자까지 동일하게 유지할 것 — 그래야 4장의 캐릭터가 일치한다.

**포즈 1 (접지 A)** — 검증 조건 3개 포함 (초안은 실패, 이 판이 2/2 성공)
```
POSE: a wide striding step - his legs are spread far apart in a big letter A shape. His LEFT boot is planted far AHEAD of his hips, clearly out in front of his body and not underneath it, with the heel down and the toe tipped up. His RIGHT boot is stretched far BEHIND his hips and touches the ground with ONLY the very tip of its toe - the heel of that rear boot is lifted clear of the ground and there must be a clearly visible gap of empty magenta background under that raised heel. The horizontal distance between his two boots must be at least as wide as his shoulders are broad. Both legs are nearly straight, not bent. Upper body and weapon stay exactly as they are, still aimed forward.
```

**포즈 2 (무릎 들기 A)**
```
POSE: caught mid-step with one foot in the air. ONLY his LEFT boot touches the ground - that leg is straight and vertical directly under his body, carrying all his weight. His RIGHT knee is bent and swung forward so his RIGHT BOOT IS RAISED HIGH IN THE AIR, roughly level with his left knee. There must be a clearly visible gap of empty magenta background between his right boot and the ground. Upper body and weapon stay exactly as they are, still aimed forward.
```

**포즈 3 (접지 B)**
```
POSE: a wide striding step, the mirror of the other stride - his legs are spread far apart in a big letter A shape. His RIGHT boot is planted far AHEAD of his hips, clearly out in front of his body and not underneath it, with the heel down and the toe tipped up. His LEFT boot is stretched far BEHIND his hips and touches the ground with ONLY the very tip of its toe - the heel of that rear boot is lifted clear of the ground and there must be a clearly visible gap of empty magenta background under that raised heel. The horizontal distance between his two boots must be at least as wide as his shoulders are broad. Both legs are nearly straight, not bent. Upper body and weapon stay exactly as they are, still aimed forward.
```

**포즈 4 (무릎 들기 B)**
```
POSE: caught mid-step with one foot in the air. ONLY his RIGHT boot touches the ground - that leg is straight and vertical directly under his body, carrying all his weight. His LEFT knee is bent and swung forward so his LEFT BOOT IS RAISED HIGH IN THE AIR, roughly level with his right knee. There must be a clearly visible gap of empty magenta background between his left boot and the ground. Upper body and weapon stay exactly as they are, still aimed forward.
```

> 헌터는 `his/him` → `her`, `boot` 는 그대로. 엔지니어는 `his` 유지.

---

## 4-5. 생성 방식 — 측정으로 확인된 것 (중요)

포즈 다양성과 캐릭터 일관성은 **트레이드오프**다. 아래는 베테랑으로 실측한 결과다.

| 방식 | 포즈 다양성 (인접 실루엣차) | 캐릭터 일관성 | 판정 |
|---|---|---|---|
| EditImage(기준 이미지 → 포즈 지시) | **8.2%** | 완벽 | 실패 — 포즈가 안 바뀜 |
| GenerateImage + `reference` 포트 | **11.8%** | 완벽 | 실패 — 포즈가 안 바뀜 |
| GenerateImage 순수 텍스트 (레퍼런스 없음) | **52.3%** | 드리프트 (팔레트 거리 42.8) | 포즈는 OK |

> **핵심**: 기준 이미지를 `reference` 든 `sourceImage` 든 물리는 순간 생성기가 원본 포즈에
> 고정된다. 포즈를 바꾸려면 **레퍼런스를 떼고 순수 텍스트로** 생성해야 한다.

### 2단계 레시피
1. **포즈 확보** — 4-1~4-3 기준 프롬프트의 `POSE:` 문단만 4-4로 교체, `reference` 연결 없이 GenerateImage
2. **캐릭터 복원** — EditImage 에 `sourceImage`=1단계 결과, `reference`=승인된 기준 이미지,
   `referenceText`="포즈·실루엣은 그대로 두고 색·장비만 레퍼런스에 맞춰라"

2단계 효과 실측: 포즈 유지(1단계 대비 실루엣차 8.0%)하면서 팔레트 거리 42.8 → 19.1 로 개선.
프레임당 40크레딧(20+20).

### 프롬프트에는 검증 가능한 조건을 넣어라
초안의 "wide striding step" 문단은 0/2 실패했다(큰 가위 대신 거의 서 있는 자세). 반면 "무릎 들기"는
2/2 성공했는데, 차이는 **눈으로 확인 가능한 조건**("부츠와 바닥 사이에 마젠타 틈이 보일 것")의 유무였다.
스트라이드 문단에 같은 성격의 조건 세 개
— ① 두 부츠 사이 거리 ≥ 어깨너비 ② 뒷발 뒤꿈치 아래에 마젠타가 보일 것 ③ 앞발은 엉덩이보다 앞 —
를 넣어 다시 쓰니 **2/2 성공**했다. 아래 4-4 는 그 수정본이다.

### 아직 남은 약점
- 2단계를 거쳐도 팔레트가 완전히 고정되지는 않는다. 프레임간 팔레트 거리는 정규화한 것끼리 7~19,
  정규화 안 한 프레임이 섞이면 24~33 으로 벌어진다.
- **전역 색 보정으로는 못 고친다.** Lab 공간 Reinhard 색 전이를 붙여 봤지만 프레임간 팔레트 편차가
  평균 21.2 → 22.6 으로 **오히려 나빠졌다**(드리프트가 바지 같은 국소 영역 색상차라서, 전역 보정은
  이미 맞은 프레임까지 흔든다). 이 방향은 시도하지 말 것.
- EditImage 노드가 진행률 70%대에서 행에 걸리는 경우가 있다. 재실행하면 진행률이 리셋되며 다시 돈다.

---

## 5. 이미지 → 스프라이트 시트 처리 파이프라인

**스크립트는 이제 [`tools/make_character_sheet.py`](../tools/make_character_sheet.py) 에 커밋돼 있다.**
세션마다 재작성할 필요 없다. 아래는 그 스크립트가 구현한 파라미터다 (Python + Pillow + scipy).

```bash
# 걷기 시트
python tools/make_character_sheet.py -o assets/sprites/run_veteran.png raw/p*.png
# 대기 이미지
python tools/make_character_sheet.py -o assets/sprites/idle_veteran.png --single raw/idle.png
```

시트 모드는 인접 실루엣 차이가 25% 미만이면 종료코드 2 로 실패를 알린다.

1. **키잉** — 테두리 픽셀의 중앙값을 키 컬러로 잡고 가장자리에서 플러드 필.
   - 색거리 허용치 `tol = 70` (흰 배경이면 60)
   - 마젠타는 HSV 색상 차 10도 이내 & 채도 ≥ 90 도 배경으로 간주(그림자·글로우 제거)
   - 갇힌 배경 구멍: 키 컬러와 색거리 48 이내면 제거 (흰 배경은 25 — 크림색 옷 보호)
   - 경계 부드럽게: `MinFilter(5)` → 원본과 0.5 블렌드 → `GaussianBlur(0.8)`
   - 디스필: 반투명 픽셀에 `(c - key*(1-a))/a`
2. **잡티 제거** — 8연결 성분 라벨링
   - 면적 2000 초과 = figure 앵커. 앵커 높이가 중앙값의 55% 미만이면 제목 텍스트로 보고 제외
   - 가로가 세로의 3배 넘는 작은 조각 = 지면선/그림자 → 제거
   - 나머지 작은 조각은 앵커 바운딩박스(12px 확장)와 겹칠 때만 그 figure에 편입
3. **정규화** — 각 figure를 **높이 150px**로 개별 리사이즈 (원본이 행마다 크기가 다른 경우가 잦음)
4. **조립** — 셀 폭 = 최대 프레임 폭 + 8, 셀 높이 = 최대 프레임 높이 + 4.
   바닥 정렬(`oy = cell_h - h - 2`), 가로 중앙 정렬. 공중 포즈는 원본 지면 기준 리프트를 최대 14px까지 반영
5. **순서** — 인접 프레임 간 실루엣 차이(대칭차/합집합)가 최대가 되는 순환 순서로 배치.
   **인접 프레임 차이 25% 미만이면 애니메이션으로 안 읽힌다** — 이 수치로 품질을 판정할 것
6. **저장** — `assets/sprites/run_<id>.png`, 대기는 `idle_<id>.png`
7. **데이터** — `data/character_db.tres` 의 해당 캐릭터 `run_frames` 를 프레임 수로 설정

### 검증 (필수)
- Godot 헤드리스 바이너리로 `--import` → 파싱 에러 0
- `scenes/Main.tscn` 실행해 `body.hframes`, `pl._run_frames`, 이동 시 프레임 0..N-1 전부 순환 확인
- 시트 폭이 프레임 수로 **정확히 나누어떨어지는지** (`width % run_frames == 0`)
- 렌더링 확인이 필요하면 `xvfb-run -a -s "-screen 0 800x1300x24" <godot> --path . --rendering-driver opengl3 <scene>` 로 캡처

---

## 6. VARCO 3D MCP 연동 메모

- 등록: `claude mcp add --transport http varco-3d https://3d.varco.ai/api/mcp`, 이후 `/mcp` 로 인증
- 설정 저장 위치: `~/.claude.json` (스코프 local/user) 또는 프로젝트 루트 `.mcp.json` (스코프 project)
- **브라우저에 커스텀 워크플로우가 열려 있어야만** 툴 호출이 중계된다
- 사용 가능 노드: `TextInput` → `GenerateImage`(count/aspectRatio/model), `EditImage`(sourceImage + referenceText로 포즈만 변경), `Generate3D`, `Rig`, `Animate` 등
- 요금(NC_MEMBER): 이미지 생성/편집 = `task:GENERATE_IMAGE_V2` **20크레딧/장**
- 기존 워크플로우(`272c3116-c792-4217-a05e-64e43e14c636`)에 좀비·보스·주인공 노드가 이미 있으니 **빈 영역(x 2700, y 4600 이후)에 새 노드를 만들 것**

### ⚠️ 원격 세션의 제약
Claude Code 원격 실행 환경에서는 `3d.varco.ai` 가 이그레스 정책에 막혀 있다
(`CONNECT tunnel failed, response 403`). MCP 호출은 브라우저를 경유해 되지만
**생성된 PNG 파일은 직접 다운로드할 수 없다.** 따라서:

- 원격 세션: 생성은 MCP로 지시 가능하지만, **결과 이미지는 사람이 채팅에 업로드**해야 판정 가능
- 로컬 Claude Code: 제약 없음 — 생성·다운로드·판정·재생성 루프를 자동으로 돌릴 수 있음

---

## 7. 새 세션 시작 시 가이드

1. 이 문서(`docs/character-sprite-handoff.md`)를 읽게 한다
2. 위 **4-1~4-3 기준 이미지 3장**을 VARCO(또는 다른 생성기)로 뽑는다
3. 결과를 채팅에 업로드 → 스타일·실루엣이 몬스터 아트와 맞는지 판정받는다
4. OK면 캐릭터당 **4-4의 걷기 4포즈를 한 장씩 따로** 생성한다 (캐릭터당 4장, 총 12장)
5. 업로드 → 5장의 파이프라인으로 시트 조립 → 검증 → 커밋 → PR → 스쿼시 머지
6. 작업 브랜치는 `claude/kenney-assets-sprites-782pbc`, 머지 후 `git checkout -B <브랜치> origin/main` 으로 재정렬

### 실패 시 판단 기준
- 인접 프레임 실루엣 차이 < 25% → 포즈가 복제된 것. 해당 컷만 재생성
- 공중 포즈에서 부츠와 바닥 사이 빈 공간이 안 보임 → 재생성
- 무기가 2개거나 프레임마다 사라짐 → 재생성
- 등신수·선 두께가 다른 캐릭터와 다름 → 스타일 문단 확인 후 재생성
