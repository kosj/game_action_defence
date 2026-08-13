# HUD Phase 2 에셋 생성 프롬프트 (6종)

> 기존 `assets/ui/frames/`(다크 건메탈 강철 + 얇은 오렌지골드 헤어라인 + 코너 리벳) 톤에 맞춘
> 복붙용 프롬프트. **6장 모두 같은 모델·같은 설정·같은 세션**에서 한 번에 뽑아야 톤이 맞는다.
>
> 공통 규칙
> - **배경: 투명 PNG** (안 되면 단색 흰/자홍 — 배치 시 제거)
> - **글자·숫자·워터마크 금지**, 오브젝트 1개, 정면 뷰, 화면 중앙
> - 나인패치용(1·2·4번)은 **가장자리가 곧고 균일**해야 함(중앙이 늘어나도 티 안 나게)
> - 크기는 "권장"이며, 정사각형만 나오는 툴이면 1024×1024 로 뽑아도 됨(배치 시 크롭/리사이즈)

## 공통 네거티브 프롬프트 (전부 동일하게 사용)
```
text, letters, numbers, watermark, logo, background scenery, photo, realistic
photograph, blurry, low-res, perspective view, 3d tilted angle, drop shadow on
ground, cropped, cut off, multiple objects, ornate filigree, fantasy engraving,
sci-fi greebles, glowing neon
```

---

## 1. hud_top_bar.png — 상단바 (권장 1024×256, 나인패치)
```
mobile game HUD top bar plate, one wide horizontal rectangle, dark gunmetal
brushed steel surface, subtle vertical gradient slightly darker at the top,
thin orange-gold hairline trim running along the bottom edge, slightly rounded
bottom corners, two small gold rivets near the bottom corners, flat front view,
clean semi-flat vector shading, subtle inner shadow, straight uniform
stretchable edges for nine-patch scaling, isolated on transparent background,
no text, crisp edges, game UI asset
```

## 2. hud_gauge_frame.png — 게이지 프레임 (권장 512×96, 나인패치, HP/보스/XP 공용)
```
slim horizontal gauge frame for a mobile game HUD, dark gunmetal steel outer
rim with a thin orange-gold hairline inset, deep dark recessed empty inner
channel, softly rounded corners, flat front view, clean semi-flat vector
shading, subtle inner shadow inside the channel, straight uniform stretchable
edges for nine-patch scaling, isolated on transparent background, no text,
crisp edges, game UI asset
```

## 3. hud_gauge_fill.png — 게이지 필 (권장 512×64, 무채색 필수)
```
horizontal energy bar fill strip for a mobile game HUD, neutral grayscale
white-to-light-gray glossy surface, soft bright highlight along the top edge,
softly rounded ends, completely straight top and bottom edges, flat front
view, clean semi-flat vector shading, no color tint, isolated on transparent
background, no text, crisp edges, game UI asset
```
> ⚠️ 반드시 **무채색(그레이스케일)** — 게임이 HP초록/보스빨강/XP시안을 코드로 입힌다.

## 4. hud_slot_small.png — 로드아웃 미니 슬롯 (권장 256×256, 나인패치)
```
small square inventory slot frame for a mobile game HUD, thin dark gunmetal
steel rim with a very thin orange-gold hairline inset, dark recessed empty
center, slightly rounded corners, minimal ornament, flat front view, clean
semi-flat vector shading, subtle inner shadow in the recessed center, straight
uniform stretchable edges for nine-patch scaling, isolated on transparent
background, no text, crisp edges, game UI asset
```
> 기존 `item_slot.png`(황동)보다 **단순·얇은 림** — 44px 로 축소돼도 뭉개지지 않게.

## 5. hud_btn_round.png — 원형 버튼 플레이트 (권장 256×256)
```
round circular metal button plate for a mobile game HUD, dark gunmetal brushed
steel face, thin orange-gold rim ring around the outer edge, subtle glossy
highlight on the upper half, slight bevel depth, perfectly centered circle,
flat front view, clean semi-flat vector shading, isolated on transparent
background, no text, no icon, crisp edges, game UI asset
```
> 중앙은 **빈 면** — 일시정지 막대 아이콘은 코드가 그린다.

## 6. hud_badge_level.png — 레벨 뱃지 (권장 256×256)
```
small circular metal badge plate for a mobile game HUD, dark steel face with a
thin orange-gold trim ring, slightly raised rim, empty flat center, subtle
soft highlight at the top, perfectly centered circle, flat front view, clean
semi-flat vector shading, isolated on transparent background, no text, no
number, crisp edges, game UI asset
```
> 중앙은 빈 면 — "Lv 46" 텍스트는 코드가 올린다.

---

## 생성 후

1. 파일명 그대로 `assets/ui/hud/` 에 저장 (또는 이미지를 세션/이슈로 전달)
2. 나인패치 마진(초기치): top_bar 40 / gauge_frame 24 / slot_small 28 — 실물 보고 조정
3. 이후 Phase 2 코드 작업(UIStyle.gauge 헬퍼 + HUD 스타일 교체)이 이 파일들을 연결한다
