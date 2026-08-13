# 인트로 배경 일러스트 프롬프트 (선택 교체용)

현재 인트로 배경(`scripts/IntroBackdrop.gd`)은 **코드 드로잉**이다 — 타이틀 아트
(`assets/ui/bg_title.png`)의 크림슨 노을·잔불 팔레트를 그대로 이어받아 폐허 도시 실루엣 3겹과
격자 송신탑(맥동 비컨)을 그린다. 별·잔불·비컨이 애니메이션되고 해상도에 자동으로 맞춰진다.

더 높은 완성도의 **일러스트 1장으로 교체**하고 싶다면 아래 프롬프트로 생성해
`assets/ui/hud/` 가 아닌 **`assets/ui/bg_intro.png`** 로 저장하면 된다. 파일이 있으면 코드가
자동으로 감지해 배경으로 쓰고, 그 위에 **잔불(ember) 애니메이션만** 얹는다.

> ⚠️ 이 경우 **송신탑은 일러스트에 포함되어야 한다**(코드는 탑을 그리지 않는다).
> 탑은 화면 **가로 65~75% 지점**에, 꼭대기에 **붉은 신호등**이 켜진 채로 그려질 것.
> 화면 중앙(세로 25~70%)에는 본문 텍스트가 올라가므로 **비워 둘 것**.

## 세로 화면용 프롬프트 (권장 비율 9:16, 예: 720×1280 또는 1080×1920)

```
A vertical portrait key art background for a mobile zombie survival game intro
screen. A ruined night city skyline in flat silhouette, three overlapping depth
layers getting darker toward the foreground, with a few small warm amber lit
windows scattered in the nearest buildings. Behind the skyline a wide crimson
red glow burns along the horizon like a distant fire, fading upward into a deep
dark maroon and then near-black starry sky. On the right side at about seventy
percent of the image width stands a tall lattice steel radio tower in
silhouette, taller than every building, with a glowing red signal light at its
very top casting a soft red halo. Small orange embers drift upward across the
scene. Clean cel-shaded vector style with bold flat shapes, limited palette of
crimson, maroon, black and warm amber, no gradients banding, cinematic and
desolate mood. The center of the image, from twenty-five to seventy percent
height, is mostly empty dark sky so text can be placed over it. No text, no
letters, no watermark, no logo, no characters, no people, no zombies, no user
interface elements, not cropped, high quality, crisp edges.
```

## 생성 후

1. `assets/ui/bg_intro.png` 로 저장 (투명 배경 불필요 — 불투명 일러스트)
2. Godot 에디터에서 열면 자동 임포트 → 인트로 실행 시 바로 반영
3. 마음에 안 들면 파일만 지우면 코드 드로잉으로 되돌아간다(폴백 내장)
