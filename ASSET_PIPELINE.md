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

### 절차

```bash
# 1) PNG 를 아래 위치에 넣는다 (tools/build_atlas.py 의 ATLASES 글롭에 걸리는 곳)
#    게임플레이 → assets/sprites/ 아래 전부 (fx/ props/ turret/ 포함, tiles/ 만 제외)
#    UI        → assets/ui/{icons,portraits,thumbs}/

# 2) 아틀라스를 다시 만든다
python3 tools/build_atlas.py

# 3) 참조는 PNG 가 아니라 생성된 AtlasTexture 를 가리킨다
#      X  res://assets/sprites/zombie_new.png
#      O  res://assets/atlas/zombie_new.tres        (게임플레이)
#      O  res://assets/atlas/ui/weapon_new.tres     (UI)
```

3번은 `.tscn` · `.tres` · `.gd` 어디서든 동일하다. `ext_resource type="Texture2D"` 가
`.tres` 를 가리켜도 정상 동작한다(AtlasTexture 는 Texture2D 다).

### 아틀라스에 넣지 않는 것

| 대상 | 이유 |
|---|---|
| `assets/tiles/*` | `texture_repeat` 로 반복 샘플링해야 해서 아틀라스에 넣을 수 없다. **`sprites/` 밖에 둔다** — 아래 참조 |
| `assets/sprites/props/*` | `PropField` 가 단일 CanvasItem 에서 한 번에 그려 배칭 영향이 작다 |
| `assets/ui/frames/*`·`hud/*` | `StyleBoxTexture` 나인패치 + 무손실 고정(아래 3절) |
| `assets/ui` 루트(배경·로고·비네트) | 한 번에 한 장만 뜨는 큰 그림이라 배칭 이득이 없다 |

캐릭터 러닝 시트는 아틀라스에 넣어도 된다 — `Sprite2D.hframes` 는 AtlasTexture 의 region 을
분할하므로 그대로 동작한다(실측 확인).

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

### 크기는 "표시 크기 × 2" 가 기준

원본을 무작정 크게 넣으면 아틀라스만 커진다. 다만 **줄여도 되는 것과 아닌 것이 갈린다**.

| 구분 | 예 | 축소 가능? |
|---|---|---|
| 코드가 크기를 정규화 | FX(`SpriteFX` size_px), 투사체(`Bullet._TEX_SIDE`), 프롭(카탈로그 `w`) | ✅ 원본을 줄여도 화면 크기 그대로 |
| 고정 스케일 | 젬(`COLLECT_SCALE`), 터렛(`SPR_SCALE`), 좀비·캐릭터(`sprite_scale`) | ❌ 줄이면 **화면에서도 작아진다** |

축소 기준은 **최대 표시 크기 × 2** 다. `display/window/stretch/mode="canvas_items"` 라
고DPI 단말에서는 2D 가 실제 해상도로 그려지므로(720 설계 → 1440 단말이면 2배) 그만큼 여유가 필요하다.

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
