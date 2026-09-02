# 캐릭터 4방향 걷기 아트 — 생성 프롬프트 / 반입 절차

> **왜 4방향인가** — 이 게임은 바닥이 수직 부감인데 캐릭터는 정면 입면이라, 위로 걸어가도
> 화면을 향해 서 있는 그림이 그대로 있다. 그 어색함을 없애는 것이 목적이다(P1-33).
>
> **코드는 이미 다 들어가 있다.** `Player.gd` 가 아래 파일명을 찾아 쓰고, 없는 방향은 측면
> 그림으로 되돌아간다. **그래서 한 장씩 넣어도 그때그때 살아나고, 하나도 없으면 지금과 똑같다.**
> 즉 이 문서의 아트를 채우는 것 외에 코드 작업은 남아 있지 않다.

---

## 0. 먼저 — 최소 목표는 **뒷모습 3장**이다

발주량을 잘못 잡으면 시작도 못 한다. 기존 아트를 실제로 열어 보고 나온 결론:

**기존 캐릭터 그림은 옆모습이 아니라 정면(카메라를 향해 서 있음)이다.** 그래서 방향별로
지금 화면이 실제로 어떤가는 이렇다:

| 이동 방향 | 지금 보이는 것 | 맞는가 |
|---|---|---|
| **아래**(카메라 쪽) | 정면 그림 | ✅ **이미 맞다** — 아트 불필요 |
| 좌 / 우 | 정면 그림을 수평 플립 | 🔶 어색하지 않다(뱀서식 관례) |
| **위**(카메라 반대) | 정면 그림 — 얼굴을 보이며 멀어진다 | ❌ **이것 하나가 틀렸다** |

즉 사용자가 말한 "상하로 움직일 때 그 방향으로 걷는 모습"에서 **실제로 없는 것은 뒷모습뿐이다.**

> ### ⭐ 최소 반입 = `idle_veteran_up.png` · `idle_hunter_up.png` · `idle_engineer_up.png`
> **정지 포즈 3장.** 시트도 아니고 아래쪽 그림도 필요 없다. 이 3장만 넣으면 위로 걸을 때
> 뒷모습이 나오고(조준도 위로 따라간다), 걷기는 기존 절차 애니메이션이 그대로 얹힌다.
> 코드가 "시트 없이 대기 그림만" 조합을 받도록 이미 만들어져 있고 검사도 그걸 지킨다.

아래 3절의 걷기 시트(6프레임 × 3방향)는 **그 다음 단계**다. 한 번에 다 하려다 실패하지 말 것 —
⚠️ 실제로 이 레포는 **걷기 시트 생성을 한 번 실패했다**(2026-09-02 이전, 다른 세션). 그 전에도
한 번 넣었다 뺐다(4절). 시트는 이 아트 파이프라인에서 가장 잘 깨지는 항목이다.

---

## 1. 파일명 규약 (코드와의 계약)

`assets/sprites/` 에 넣는다. `build_atlas.py` 가 `assets/sprites/*.png` 를 통째로 게임플레이
아틀라스에 넣으므로 **경로만 맞추면 `.tres` 는 자동 생성**된다.

| 방향 | 걷기 시트 | 대기 포즈 | 비고 |
|---|---|---|---|
| 측면(좌우 공용) | `run_<id>.png` | `idle_<id>.png` | **이미 있는 파일** — 좌우는 수평 플립으로 공용 |
| 위(등을 보인 뒷모습) | `run_<id>_up.png` | `idle_<id>_up.png` | 신규 |
| 아래(정면) | `run_<id>_down.png` | `idle_<id>_down.png` | 신규 |

`<id>` 는 `veteran` · `hunter` · `engineer` 세 가지다.

⚠️ **상/하 그림은 절대 좌우로 뒤집히지 않는다.** 정면·후면이라 뒤집으면 무기가 반대 손으로
간다. 코드가 그 방향에서 플립을 빼고(`Player._animate_walk` 의 `flip`), 회귀 검사가 지킨다.

⚠️ **세 방향의 프레임 수는 같아야 한다.** `CharacterData.run_frames` 하나를 세 방향이 공유한다.
칸 수가 다르면 걷다가 방향을 바꿀 때 보폭이 튄다.

---

## 2. 스펙

- **크기** — 기존 `idle_<id>.png` 와 **같은 높이**로 맞춘다(현재 세 캐릭터 모두 150px 높이).
  높이가 달라지면 `sprite_scale`(0.66)과 `shadow_ref_width` 가 어긋나 캐릭터만 혼자 커진다.
- **배경 투명 · 타이트 크롭**. 월드에 놓이는 유닛이므로 흰 프린지를 검정 외곽선으로 바꾼다:
  ```sh
  python3 tools/make_icon.py -o assets/sprites/run_veteran_up.png --height 150 --black-halo raw/x.png
  ```
  ⚠️ 세로가 아닌 `--max`(긴 변)를 쓰면 가로로 긴 시트가 통째로 작아진다. **반드시 `--height`.**
- **시트 배열** — 가로 균등 분할, 한 줄. `hframes` 가 폭을 정확히 나눠야 하므로
  **시트 폭 = 칸 폭 × 프레임 수**여야 한다(`verify_character_sheets.gd` 가 검사한다).
- **0번 칸은 다리를 모은 중립 포즈**로 둔다 — 대기 그림이 없을 때 이 칸이 정지 포즈로 쓰인다.
- **프레임 수** — 6칸 권장(아래 4절 예산 참고).

---

## 3. 프롬프트

세 캐릭터의 기존 아트와 **같은 모델·같은 시드·같은 설정**으로 뽑아야 톤이 맞는다.
가장 확실한 방법은 기존 `idle_<id>.png` 를 참조 이미지로 넣고 **시점만 바꾸라고 지시**하는 것이다.

### 스타일 베이스 (공통, 모든 프롬프트에 붙인다)

```
2D game character sprite, full body, cel-shaded comic style with bold dark
outlines, flat saturated colors, soft top-left lighting, clean silhouette,
isolated on transparent background, no text, no watermark, no ground shadow,
no background scenery, consistent character design and equipment across frames
```

### 네거티브 프롬프트 (공통)

```
text, letters, watermark, signature, frame, border, background scenery, ground
shadow, blurry, low-res, cropped, cut off, extra limbs, changing outfit,
changing weapon, inconsistent colors between frames, motion blur
```

### 방향별 시점 지시

| 방향 | 시점 문구 (주제 앞에 붙인다) |
|---|---|
| `_down` | `seen from the front, facing the viewer, walking toward the camera` |
| `_up` | `seen from directly behind, back view, facing away from the viewer, walking away from the camera — face not visible, back of the head and shoulders` |

### 캐릭터별 주제

| id | 주제(subject) |
|---|---|
| `veteran` | `a rugged bearded soldier in a red bandana, olive tank top and tactical vest, combat boots, holding an assault rifle` |
| `hunter` | `a slim archer in a green hooded cloak with a ponytail, leather bracers and tall boots, holding a crossbow` |
| `engineer` | `a practical engineer in work overalls and a tool harness, holding a compact nailgun` |

### 걷기 시트 지시 (시트로 뽑을 때)

```
walk cycle sprite sheet, 6 frames in a single horizontal row, evenly spaced,
identical character and equipment in every frame, only the legs and arms change,
frame 1 is a neutral standing pose with feet together
```

⚠️ **이 부분이 가장 잘 실패한다.** 지난번에 시트를 뺀 이유가 그것이다 — *"생성 아트가 프레임마다
팔레트·장비가 미묘하게 흔들려 시트를 돌리면 오히려 어색했다"*(`CharacterData.run_frames` 주석).
프레임을 따로따로 뽑지 말고 **한 장의 시트로 한 번에** 뽑고, 그래도 흔들리면 프레임 수를 줄이거나
대기 포즈만(`idle_<id>_up.png`) 넣어 절차 걷기로 가는 편이 낫다. **코드가 그 조합도 받는다.**

---

## 4. 아틀라스·용량 예산 ⚠️

지금 게임플레이 아틀라스는 **1024×1024 / 814KB** 다. 시트를 넣으면 **한 변이 2048 로 올라간다** —
예전에 측면 시트만 있을 때 실제로 그랬고, 그래서 시트를 저장소에서 뺐다.

- `build_atlas.py` 의 `MAX_SIZE = 2048` 이 **하드 상한**이다. 넘으면 스크립트가 그 자리에서 죽는다.
- 2048² 에서 기존 내용물을 빼고 남는 자리로 대략 **100칸 안팎**이 들어간다(칸 131×158, 셸프 패킹
  손실 포함한 어림). 3캐릭터 × 3방향 × 6프레임 = **54칸**이면 여유가 있다. 12프레임쯤에서 빠듯해진다.
- 웹 pck 상한 15MB, 현재 약 12MB. 아틀라스가 2048² 로 커지는 몫이 여기 얹힌다.

**정확한 판정은 어림이 아니라 실행이다:**

```sh
python3 tools/build_atlas.py                                   # 안 들어가면 여기서 죽는다
godot --headless --path . --script res://tools/check_atlas.gd  # CI 게이트와 동일
```

---

## 5. 반입 절차

```sh
pip install pillow                       # build_atlas.py 에 필요 — 없으면 그냥 죽는다

# 1. 그림을 규약대로 만든다
python3 tools/make_icon.py -o assets/sprites/run_veteran_up.png --height 150 --black-halo raw/veteran_up.png
#    ... 방향·캐릭터별로 반복

# 2. 아틀라스 재생성 (.tres 가 자동으로 생긴다)
python3 tools/build_atlas.py

# 3. run_frames 를 프레임 수로 바꾼다 — .tres 가 아니라 생성기를 고친다(CLAUDE.md §2)
#    tools/gen_character_data.gd 의 각 캐릭터 딕셔너리에 "run_frames": 6 을 넣고
godot --headless --path . --script res://tools/gen_character_data.gd

# 4. 검증
godot --headless --path . --import
godot --headless --path . --script res://tools/check_atlas.gd
godot --headless --path . --script res://tools/verify_character_sheets.gd   # 칸 수 ↔ 시트 폭
godot --headless --path . --script res://tools/verify_player_facing.gd      # 방향 전환·폴백

# 5. 눈으로 확인 — 헤드리스는 그려진 것이 화면 밖인지 알려주지 않는다
xvfb-run -a godot --path . --fixed-fps 60 --script res://tools/shot_timeline.gd
```

---

## 6. 총구 위치

상/하 그림은 무기를 뻗은 지점이 측면과 다르다. 그림에서 무기 끝 픽셀을 재어
`tools/gen_character_data.gd` 의 캐릭터 딕셔너리에 넣는다:

```gdscript
"muzzle_offset_up":   Vector2(2, -70),    # 위를 향할 때 총구(Body 로컬, 중심이 원점)
"muzzle_offset_down": Vector2(-4, 40),
```

비워 두면(`Vector2.ZERO`) 측면값을 그대로 쓴다 — 총알이 몸통에서 나오면 이 값을 안 넣은 것이다.

---

## 7. 남은 것 — 좀비·보스

이 문서는 **플레이어 3종**만 다룬다. 좀비 11종·보스 3종은 아직 측면 한 장이므로, 플레이어만
4방향이 되면 그 14종과 시점이 어긋난다. 먼저 플레이어로 체감을 확인하고, 값어치가 있으면
별도 항목으로 잡는다(`Zombie.gd` 는 `_d_tex` 한 장을 바꿔 끼우는 구조라 코드 변경은 비슷하게 작지만,
아트가 14종 × 2방향이라 발주량이 다르다).
