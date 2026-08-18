# 무기 / 패시브 아이콘 생성 프롬프트

> 게임 인벤토리·레벨업 카드·상점용 아이콘 세트. **일관된 스타일**이 핵심이므로 아래 "스타일 베이스"를
> 모든 프롬프트에 붙이고, 되도록 **한 번에(batch) 같은 모델·같은 설정**으로 뽑아 톤을 맞춘다.

## 권장 설정
- **크기:** 512×512 (또는 1024×1024). 정사각형.
- **배경:** **투명(alpha) PNG**. 안 되면 단색(흰/자홍) 배경 — 업로드 후 자동 제거 가능.
- **구성:** 오브젝트 1개, 화면 중앙, 여백(패딩) 12~15%, **글자·워터마크 없음**.
- **시점:** 전체 세트 통일(정면 또는 3/4 뷰 중 하나로 고정).
- **일관성 팁:** 같은 시드/스타일 프리셋 유지, 같은 광원 방향(좌상단), 같은 아웃라인 두께.

## 스타일 베이스 (모든 프롬프트 앞/뒤에 공통으로 붙이기)
```
mobile game inventory icon, single centered object, flat vector shading with
soft cel-shaded gradients, bold clean silhouette, thick subtle dark outline,
top-left soft lighting, vibrant saturated colors, slight glossy highlight,
game UI item icon, isolated on transparent background, no text, no background
scenery, square composition, high detail, crisp
```

## 네거티브 프롬프트 (공통)
```
text, letters, watermark, signature, frame, border, multiple objects, cluttered,
photo, realistic photograph, blurry, low-res, background scenery, drop shadow on
ground, human hands, cropped, cut off
```

---

## 무기 아이콘 (기본 16종)
> 각 줄: `id — 표시명 → [주제] (강조색)`. 프롬프트 = **주제 + 스타일 베이스**.

| id | 프롬프트 주제(subject) | 강조색 |
|---|---|---|
| gun | a sleek semi-automatic pistol sidearm, side profile | amber/gold |
| orb | two orbiting steel throwing blades / spinning saw-blade orbs | cyan |
| lightning | a crackling forked lightning bolt, energy sparks | violet |
| garlic | a glowing garlic bulb radiating a soft aura ring | teal-green |
| shotgun | a pump-action combat shotgun, side profile | orange |
| machinegun | a compact submachine gun, side profile | yellow-green |
| crossbow | a crossbow with a loaded bolt, side profile | steel blue |
| flamethrower | a flamethrower nozzle spewing a cone of fire | fiery orange |
| molotov | a lit molotov cocktail bottle with a burning rag | orange-red |
| mine | a round proximity land mine with a blinking red light | orange |
| spikedbat | a wooden baseball bat wrapped with nails/spikes | tan/gold |
| chainsaw | a rugged chainsaw, side profile | steel white |
| turret | a small deployable auto-turret sentry on a tripod | steel blue |
| drone | a small hovering quad combat drone with a gun pod | teal |
| tesla | a tesla coil tower emitting electric arcs | electric blue |

### 예시(그대로 복붙용) — shotgun
```
a pump-action combat shotgun in side profile, mobile game inventory icon,
single centered object, flat vector shading with soft cel-shaded gradients,
bold clean silhouette, thick subtle dark outline, top-left soft lighting,
warm orange accents, glossy highlight, isolated on transparent background,
no text, square composition, high detail, crisp
```

## 무기 진화체 아이콘 (12종, 선택)
> 진화는 "베이스 주제를 극적으로 강화 + 황금 에너지 광휘"로. 프롬프트 주제 뒤에 아래 문구 추가:
```
, dramatically upgraded legendary version, glowing golden energy aura,
more menacing and ornate, premium epic upgrade
```
| 진화 id (베이스) | 베이스 주제 재사용 |
|---|---|
| railgun (gun) · gatling (machinegun) · ballista (crossbow) | 총기 → 강화판 |
| dragonsbreath (shotgun) · inferno (flamethrower) · napalm (molotov) | 화염 강화판 |
| sawstorm (orb) · thunderstorm (lightning) · stormcoil (tesla) | 회전/전기 강화판 |
| sanctuary (garlic) · claymore (mine) | 오라/폭발 강화판 |

---

## 패시브 아이콘 (10종)
| id | 표시명 | 프롬프트 주제(subject) | 강조색 |
|---|---|---|---|
| armor | Body Armor | a bulletproof tactical vest / body armor | green |
| swift | Sneakers | a sporty running shoe with speed streaks | grey-blue |
| haste | Energy Drink | an energy drink can with a lightning emblem | amber |
| crit | Scope | a rifle scope with a red crosshair reticle | amber |
| magnet | Magnet | a red horseshoe magnet with attraction sparkles | grey-blue |
| regen | First Aid | a first aid kit box with a white cross | green |
| ammo_belt | Ammo Belt | a bandolier belt of golden bullets | amber |
| gunpowder | Gunpowder | a gunpowder barrel/keg (or powder horn) with a spark | amber |
| battery | Battery | a glowing battery cell with an energy charge | grey-blue |
| rabbits_foot | Rabbit's Foot | a lucky rabbit's foot charm with a four-leaf clover | green |

---

## 파일명 규칙 (업로드 후 바로 매핑되도록)
- 무기: `assets/ui/icons/weapon_<id>.png` (예: `weapon_shotgun.png`)
- 진화: `assets/ui/icons/weapon_<id>.png` (예: `weapon_dragonsbreath.png`)
- 패시브: `assets/ui/icons/passive_<id>.png` (예: `passive_armor.png`)

> 위 `id` 는 게임 데이터의 실제 키다. 파일명을 이 규칙으로 주면 코드 배선이 자동에 가깝게 된다.
