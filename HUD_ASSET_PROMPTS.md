# HUD Phase 2 에셋 생성 프롬프트 (6종 · 단일 블록 완결형)

> 기존 `assets/ui/frames/`(다크 건메탈 강철 + 얇은 오렌지골드 헤어라인 + 코너 리벳) 톤에 맞춘
> 프롬프트. 각 블록 하나에 스타일·구도·배경·금지 요소까지 **필요한 텍스트가 전부** 들어 있어
> 네거티브 프롬프트 칸이 없는 툴에서도 그대로 한 번에 붙여넣으면 된다.
>
> - **6장 모두 같은 모델·같은 설정·같은 세션**에서 한 번에 생성해야 톤이 맞는다.
> - 크기는 "권장"이며, 정사각형만 지원하는 툴이면 1024×1024 로 뽑아도 됨(배치 시 크롭/리사이즈).
> - 생성 후 파일명 그대로 `assets/ui/hud/` 에 저장하거나 이미지를 세션으로 전달.

## 1. hud_top_bar.png — 상단바 (권장 1024×256)
```
A single wide horizontal rectangular top bar plate for a mobile game HUD, in a
dark gunmetal brushed steel style with a subtle vertical gradient that is
slightly darker at the top, a thin orange-gold hairline trim running along the
bottom edge, slightly rounded bottom corners, and two small gold rivets near
the bottom corners. Flat straight-on front view, clean semi-flat vector
shading with a subtle inner shadow, crisp edges. The left, right and top edges
must be perfectly straight and uniform so the image can be stretched as a
nine-patch UI element. Wide 4:1 horizontal banner composition, the plate fills
the frame, isolated on a fully transparent background. This is a game UI
asset: absolutely no text, no letters, no numbers, no watermark, no logo, no
background scenery, no photo realism, no perspective or tilted 3D angle, no
drop shadow on a ground, only this one object, not cropped or cut off, no
ornate filigree or fantasy engraving, no sci-fi greebles, no glowing neon.
```

## 2. hud_gauge_frame.png — 게이지 프레임 (HP/보스/XP 공용, 권장 512×96)
```
A single slim horizontal gauge frame for a mobile game HUD, in a dark gunmetal
steel style: a thin outer rim with a very thin orange-gold hairline inset, and
a deep dark recessed empty inner channel where a health bar fill would sit,
with softly rounded corners. Flat straight-on front view, clean semi-flat
vector shading with a subtle inner shadow inside the channel, crisp edges. All
four edges must be straight and uniform so the image can be stretched as a
nine-patch UI element. Wide horizontal composition around 5:1, the frame fills
the image, isolated on a fully transparent background. This is a game UI
asset: absolutely no text, no letters, no numbers, no watermark, no logo, no
background scenery, no photo realism, no perspective or tilted 3D angle, no
drop shadow on a ground, only this one object, not cropped or cut off, no
ornate filigree or fantasy engraving, no sci-fi greebles, no glowing neon.
```

## 3. hud_gauge_fill.png — 게이지 필 (권장 512×64, 무채색 필수)
```
A single horizontal energy bar fill strip for a mobile game HUD, rendered
entirely in neutral grayscale with no color tint at all: a white-to-light-gray
glossy surface with one soft bright highlight running along the top edge, and
softly rounded left and right ends. The top and bottom edges are completely
straight. Flat straight-on front view, clean semi-flat vector shading, crisp
edges. Wide horizontal composition around 6:1, the strip fills the image,
isolated on a fully transparent background. The game engine will tint this
strip green, red or cyan at runtime, so it must stay pure grayscale. This is a
game UI asset: absolutely no text, no letters, no numbers, no watermark, no
logo, no background scenery, no photo realism, no perspective or tilted 3D
angle, no drop shadow on a ground, only this one object, not cropped or cut
off, no color, no pattern, no glowing neon.
```

## 4. hud_slot_small.png — 로드아웃 미니 슬롯 (권장 256×256)
```
A single small square inventory slot frame for a mobile game HUD, in a dark
gunmetal steel style: a thin steel rim with a very thin orange-gold hairline
inset, a dark recessed completely empty center, slightly rounded corners, and
minimal ornament because the slot will be displayed very small at 44 pixels.
Flat straight-on front view, clean semi-flat vector shading with a subtle
inner shadow in the recessed center, crisp edges. All four edges must be
straight and uniform so the image can be stretched as a nine-patch UI element.
Perfect square composition, the slot fills the frame, isolated on a fully
transparent background. This is a game UI asset: absolutely no text, no
letters, no numbers, no icon inside the slot, no watermark, no logo, no
background scenery, no photo realism, no perspective or tilted 3D angle, no
drop shadow on a ground, only this one object, not cropped or cut off, no
ornate filigree or fantasy engraving, no sci-fi greebles, no glowing neon.
```

## 5. hud_btn_round.png — 원형 버튼 플레이트 (일시정지용, 권장 256×256)
```
A single round circular metal button plate for a mobile game HUD, in a dark
gunmetal brushed steel style: a steel face with a thin orange-gold rim ring
around the outer edge, a subtle glossy highlight on the upper half, and a
slight bevel depth. The center of the button face is empty flat metal because
a pause icon will be drawn on top by the game code. A perfectly centered
circle in a square composition, flat straight-on front view, clean semi-flat
vector shading, crisp edges, isolated on a fully transparent background. This
is a game UI asset: absolutely no text, no letters, no numbers, no icon, no
symbol on the face, no watermark, no logo, no background scenery, no photo
realism, no perspective or tilted 3D angle, no drop shadow on a ground, only
this one object, not cropped or cut off, no ornate filigree, no sci-fi
greebles, no glowing neon.
```

## 6. hud_badge_level.png — 레벨 뱃지 (권장 256×256)
```
A single small circular metal badge plate for a mobile game HUD, in a dark
steel style with a thin orange-gold trim ring and a slightly raised rim, an
empty flat dark center face where a level number will be drawn later by the
game code, and a subtle soft highlight at the top. A perfectly centered circle
in a square composition, flat straight-on front view, clean semi-flat vector
shading, crisp edges, isolated on a fully transparent background. This is a
game UI asset: absolutely no text, no letters, no numbers, no symbol on the
face, no watermark, no logo, no background scenery, no photo realism, no
perspective or tilted 3D angle, no drop shadow on a ground, only this one
object, not cropped or cut off, no ornate filigree, no sci-fi greebles, no
glowing neon.
```

---

## 생성 후

1. 파일명 그대로 `assets/ui/hud/` 에 저장 (또는 이미지를 세션/이슈로 전달)
2. 나인패치 마진(초기치): top_bar 40 / gauge_frame 24 / slot_small 28 — 실물 보고 조정
3. 이후 Phase 2 코드 작업(UIStyle.gauge 헬퍼 + HUD 스타일 교체)이 이 파일들을 연결한다
