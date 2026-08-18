# 에셋 파이프라인 — 새 이미지·글자를 추가할 때

> 이 프로젝트는 **모바일 웹(WebGL)** 이 주 타깃이라, 에셋을 그냥 추가하면 조용히 성능이
> 떨어지는 구조가 몇 군데 있다. 눈으로는 정상으로 보이고 프레임만 깎이기 때문에 알아채기
> 어렵다. 그래서 규칙을 CI 검사로 강제해 두었다 — 아래 절차만 지키면 된다.

---

## 1. 스프라이트(PNG)를 추가할 때

### 왜 그냥 추가하면 안 되나

Godot 의 2D 배칭은 **연속해서 그리는 아이템이 같은 텍스처·같은 머티리얼일 때만** 하나로 묶인다.
그런데 `Main` 은 `y_sort_enabled = true` 라 좀비들이 Y 좌표 순서로 정렬되고, 좀비 하나는
그림자 + 몸통 두 스프라이트다. 텍스처가 서로 다르면 그리는 순서가

```
shadow.png → zombie_walker.png → shadow.png → zombie_brute.png → ...
```

이 되어 **아이템마다 배치가 끊긴다**. 좀비 300마리면 그것만으로 약 600 드로우 콜이었다.
그래서 이 스프라이트들은 아틀라스(`assets/atlas/gameplay.png`) 한 장으로 묶여 있다.

### 아틀라스는 6장이다 — 넣을 곳을 먼저 고른다

| 아틀라스 | 원본 위치 | `.tres` 위치 | 언제 로드되나 |
|---|---|---|---|
| `gameplay` | `assets/sprites/{,fx/,turret/}*.png` | `assets/atlas/*.tres` | 항상 |
| `ui` | `assets/ui/icons/*.png` | `assets/atlas/ui/*.tres` | 항상 |
| `menu` | `assets/ui/{portraits,thumbs}/*.png` | `assets/atlas/menu/*.tres` | **메인메뉴에서만** |
| `props/suburb` | `assets/sprites/props/suburb/*.png` | `assets/atlas/props/suburb/*.tres` | **그 테마를 고른 판에서만** |
| `props/city` | `assets/sprites/props/city/*.png` | `assets/atlas/props/city/*.tres` | 〃 |
| `props/lab` | `assets/sprites/props/lab/*.png` | `assets/atlas/props/lab/*.tres` | 〃 |

오른쪽 칸이 이 표의 요점이다. **배칭 때문에 나누는 게 아니라 VRAM 때문에 나눈다.**

- 프롭: 한 판에서 뜨는 테마는 하나뿐인데 한 장에 합치면 안 쓰는 두 테마까지 늘 올라간다.
  `PropField` 는 선택 테마의 폴더만 `load()` 하므로 나머지 두 장은 아예 열리지 않는다.
- 메뉴: 초상화 3장 + 테마 썸네일 3장은 원본이 커서(357~512px) 이것들만으로 `ui` 시트 면적의
  60% 를 먹고 한 변을 2048 로 밀어올렸다 — 그 16MB 가 게임 내내 상주했다. 갈라 두니
  `ui` 가 1024×1024(4MB)로 내려갔다.

**"항상" 이 아닌 칸에 넣으려면 조건이 있다** — 그 시트를 물고 있는 참조가 전부 끊겨야 실제로
해제된다. 셋 다 만족해야 한다.

1. `preload`(= `const`) 로 잡지 않는다. `preload` 는 스크립트가 로드되는 순간 영구히 물린다
2. `.tscn`/`.tres` 의 `ext_resource` 로 고정하지 않는다 — 씬이 살아 있는 한 같이 산다
3. 그 화면을 벗어날 때 씬이 실제로 해제된다(`change_scene_to_file` 등)

셋 중 하나라도 어기면 폴더만 갈라지고 VRAM 은 그대로다. 검증은 실측이 확실하다 —
인게임 씬·아이콘을 전부 `load()` 한 뒤 `ResourceLoader.has_cached("res://assets/atlas/menu.png")`
가 `false` 인지 본다(실제로 이 방법으로 확인했다).

> **새 프롭을 추가할 때는 폴더 = 테마 id** 다(`suburb`/`city`/`lab` — `ThemeData.id`).
> 세 곳이 같은 이름을 쓴다: `assets/sprites/props/<테마>/`, `build_atlas.py` 의
> `ATLASES["props_<테마>"]`, `PropField._CATALOG` 의 `"theme"` 값.
> 여러 테마에서 쓰고 싶은 프롭은 **한 테마에만 두고 그 테마 전용으로 취급한다**(중복 저장 금지).
> 실제로 `prop_wreck_car` 는 도심 소속이고, 도심 전용 기믹인 `BurningCar` 가 같은 시트를 쓴다.

### 절차

```bash
# 1) PNG 를 위 표의 "원본 위치" 에 넣는다

# 2) 아틀라스를 다시 만든다
python3 tools/build_atlas.py

# 3) 참조는 PNG 가 아니라 생성된 AtlasTexture 를 가리킨다
#      X  res://assets/sprites/zombie_new.png
#      O  res://assets/atlas/zombie_new.tres              (게임플레이)
#      O  res://assets/atlas/ui/weapon_new.tres           (인게임 UI 아이콘)
#      O  res://assets/atlas/menu/portrait_new.tres       (메뉴 전용)
#      O  res://assets/atlas/props/city/prop_new.tres     (도심 프롭)
```

3번은 `.tscn` · `.tres` · `.gd` 어디서든 동일하다. `ext_resource type="Texture2D"` 가
`.tres` 를 가리켜도 정상 동작한다(AtlasTexture 는 Texture2D 다).

원본 PNG 를 지우면 `build_atlas.py` 가 짝이 없어진 `.tres` 를 **자동으로 정리한다**. 남겨두면
region 이 그 자리에 새로 들어온 다른 그림을 가리켜 엉뚱한 스프라이트가 그려진다.

### 아틀라스에 넣지 않는 것

| 대상 | 이유 |
|---|---|
| `assets/tiles/*` | `texture_repeat` 로 반복 샘플링해야 해서 아틀라스에 넣을 수 없다. **`sprites/` 밖에 둔다** — 아래 참조 |
| `assets/ui/frames/*`·`hud/*` | `StyleBoxTexture` 나인패치 + 무손실 고정(아래 3절) |
| `assets/ui` 루트(배경·로고·비네트) | 한 번에 한 장만 뜨는 큰 그림이라 배칭 이득이 없다 |

캐릭터 러닝 시트는 아틀라스에 넣어도 된다 — `Sprite2D.hframes` 는 AtlasTexture 의 region 을
분할하므로 그대로 동작한다(실측 확인).

### 안 쓰는 그림은 저장소에 두지 않는다

아틀라스에서 안 쓰는 그림은 "용량이 조금 늘어나는" 정도가 아니다. **시트 한 변이 한 단계
올라가면 VRAM 이 4배가 된다.** 실제로 러닝 시트 3장 + 옛 캐릭터 4장(쓰이지 않던 것)을 빼자
게임플레이 시트가 2048×2048 → 1024×1024 로 내려갔다(16MB → 4MB).

그래서 **아트를 교체하면 옛 PNG 를 같은 커밋에서 지운다.** 되살릴 일이 생기면 git 히스토리에
있다. "나중에 쓸지도 모르니 남겨둔다" 는 항상 시트 한 변을 잡아먹는다.

판정 기준은 "파일이 참조되는가" 가 아니라 **"런타임에 실제로 그려지는가"** 다. 두 번 걸렸다.
- `run_<id>.png` — `Player.gd` 가 경로를 문자열로 조립해 참조가 grep 에 안 잡혔다. 실제로는
  세 캐릭터 모두 `run_frames = 0` 이라 **한 번도 로드되지 않았다**.
- `player_<id>.png` — `CharacterData.sprite_path` 가 가리켜 "쓰는 것" 처럼 보였지만,
  `_fit_shadow()` 가 `get_size().x` **숫자 하나** 를 얻으려고 load 할 뿐 그리지는 않았다.
  지금은 그 숫자를 `CharacterData.shadow_ref_width` 로 들고 있다. 그림 하나를 폭 하나 때문에
  시트에 남기지 말 것.

### 원본은 익스포트에서 제외된다

아틀라스에 들어간 원본 PNG 는 `export_presets.cfg` 의 `exclude_filter` 로 웹 빌드에서 빠진다.
안 그러면 아틀라스와 원본이 **둘 다** pck 에 들어가 1.4MB 가 그대로 중복된다.

> ⚠️ **Godot 의 와일드카드는 `/` 까지 매칭한다.** `assets/sprites/*.png` 는 하위 폴더인
> `assets/sprites/tiles/tile_grass.png` 까지 지운다. 실제로 이것 때문에 바닥 타일이 빌드에서
> 통째로 사라진 적이 있다(에디터에서는 멀쩡해 더 헷갈린다). 그래서 **아틀라스에 못 넣는 것은
> `assets/sprites/` 밖에 둔다** — 타일이 `assets/tiles/` 에 있는 이유다.
>
> `python3 tools/build_atlas.py --check` 가 "제외 대상인데 아틀라스에도 없는 파일"을 찾아
> 빌드를 실패시킨다. 새 폴더를 추가할 때는 `ATLASES` 와 `EXPORT_EXCLUDE` 를 함께 갱신할 것.
>
> 와일드카드가 `/` 를 삼키는 성질은 뒤집어 쓰면 편하다. `exclude_filter` 는 **폴더 하나에
> 패턴 하나**만 두면 하위 폴더까지 다 걸린다 — `assets/sprites/*.png` 하나가
> `props/city/*.png` 까지 덮는다. 그래서 `exclude_filter` 의 항목과 `EXPORT_EXCLUDE` 의
> 접두사는 **1:1 로 같은 4개**다. 이 대응이 깨지면 `--check` 의 검사가 헐거워진다.

### 크기는 "표시 크기 × 2" 가 기준

원본을 무작정 크게 넣으면 아틀라스만 커진다. 다만 **줄여도 되는 것과 아닌 것이 갈린다**.

| 구분 | 예 | 축소 가능? |
|---|---|---|
| 코드가 크기를 정규화 | FX(`SpriteFX` size_px), 투사체(`Bullet._TEX_SIDE`), 프롭(카탈로그 `w`), 상자(`CHEST_DRAW_PX`) | ✅ 원본을 줄여도 화면 크기 그대로 |
| 고정 스케일 | 젬(`COLLECT_SCALE`), 터렛(`SPR_SCALE`), 좀비·캐릭터(`sprite_scale`) | ❌ 줄이면 **화면에서도 작아진다** |

축소 기준은 **최대 표시 크기 × 2** 다. `display/window/stretch/mode="canvas_items"` 라
고DPI 단말에서는 2D 가 실제 해상도로 그려지므로(720 설계 → 1440 단말이면 2배) 그만큼 여유가 필요하다.

> 아래쪽 표는 "원본을 줄이면 화면도 줄어든다" 는 경고지만, **화면에서도 줄이고 싶을 때는
> 원본을 줄이는 것이 맞는 방법**이다. 스케일 상수를 건드리면 트윈·자석·수집 연출이 전부
> 그 상수를 곱해 쓰고 있어 같이 틀어진다. 젬을 0.8배로 줄인 것이 이 경우다 —
> `xp_gem.png` 80×72 → 64×58 로 리샘플했고 `COLLECT_SCALE` 은 0.4 그대로다
> (화면 32×28.8px → 25.6×23.2px).

넣어야 할지 애매하면 기준은 하나다 — **`Main` 아래에서 y_sort 스트림에 섞여 그려지는가?**

### 검사

```bash
python3 tools/build_atlas.py --check          # 아틀라스가 원본과 최신인지
godot --headless --script res://tools/check_atlas.gd   # 직접 참조 / 크기 불일치
```

CI(`Check texture atlas`)가 같은 검사를 돌려 **빌드를 실패시킨다**. 잡는 것은 두 가지다.
1. 아틀라스 대상 스프라이트를 `.png` 경로로 직접 참조 → 그 스프라이트만 배칭이 끊긴다
2. AtlasTexture region 크기가 원본과 다름 → `get_size()` 로 스케일·그림자를 잡는 코드가 조용히 틀어진다

---

## 2. 새 문자열(한글·일본어)을 추가할 때

CJK 폰트는 **실제로 표시하는 글자만** 남긴 서브셋이다(2.36MB → 0.22MB). 지원 언어는
`Locale.SUPPORTED = ["en", "ko", "ja"]` 세 가지이며, 세 언어에서 쓰는 글자를 모두 담고 있다.

폰트에 없는 글자를 쓰면 화면에 **두부(□)** 로 나온다. 그래서:

```bash
godot --headless --script res://tools/check_font_coverage.gd   # CI 도 이걸 돌린다
```

검사가 실패하면 원본 Noto Sans CJK 를 받아 다시 서브셋해야 한다 —
자세한 안내는 `tools/subset_fonts.py` 의 docstring 참고.

> 이미 알려진 결손: 일본어 UI 의 한자 12자(`体 先 入 分 別 延 数 末 端 見 購 実`)는
> **원본 폰트에도 없어** 서브셋 이전부터 두부였다. `tools/font_known_absent.txt` 에 기록돼
> 있어 CI 를 막지 않는다. 고치려면 위 재서브셋 절차가 필요하다.

---

## 3. 텍스처 압축 기본값

`project.godot` 의 `[importer_defaults]` 가 텍스처 기본값을 **손실 압축(WebP, 품질 0.95)** 으로
잡는다. `.import` 파일은 `.gitignore` 대상이라 CI 가 매 빌드 재생성하고, 그때 이 기본값이 적용된다.
따라서 **새 PNG 는 아무것도 안 해도 자동으로 손실 압축**된다.

예외가 하나 있다 — `assets/ui/frames/*` 와 `assets/ui/hud/*` 는 `StyleBoxTexture` 나인패치로
**늘려서** 쓰기 때문에 테두리의 손실 아티팩트가 띠로 번져 보인다. 이 폴더의 `.import` 는
무손실(`compress/mode=0`)로 고정해 저장소에 커밋해 두었고, `.gitignore` 에 예외가 있다.

**나인패치로 쓸 새 UI 텍스처를 추가한다면** 이 두 폴더 중 하나에 넣어야 같은 예외가 적용된다.

---

## 4. 오디오

BGM 은 96kb/s 모노로 재인코딩해 두었다(원본 190~210kb/s 스테레오). 새 BGM 도 같은 기준으로
맞추는 것이 좋다 — 웹 pck 는 전량 다운로드해야 첫 프레임이 뜨므로 오디오가 곧 초기 로딩 시간이다.

```bash
ffmpeg -i in.mp3 -ac 1 -ar 44100 -c:a libmp3lame -b:a 96k out.mp3
```

효과음(OGG)은 합계가 작아 그대로 두면 된다.

---

## 5. 용량 상한

CI 의 `Check build size` 가 웹 `index.pck` 를 **15MB** 상한으로 검사한다(현재 약 12MB).
에셋을 크게 추가하면 여기서 걸린다. 의도한 증가라면 워크플로의 `LIMIT_KB` 를 함께 올린다.

---

## 관련 파일

| 파일 | 역할 |
|---|---|
| `tools/build_atlas.py` | 아틀라스 + AtlasTexture 생성 (`--check` 로 최신 확인) |
| `tools/check_atlas.gd` | CI: 직접 참조·크기 불일치 검사 |
| `tools/subset_fonts.py` | 폰트 서브셋 재생성 |
| `tools/check_font_coverage.gd` | CI: 폰트 글리프 커버리지 검사 |
| `OPTIMIZATION_PLAN.md` | 최적화 작업 전체 기록과 남은 과제 |
