# 궁극기 사운드 생성 프롬프트

> 📄 **바로 붙여넣을 영문 프롬프트는 [`SOUND_PROMPTS_EN.md`](SOUND_PROMPTS_EN.md) 참고** —
> 스타일 베이스가 각 프롬프트에 합쳐진 완결형이라 조립 없이 한 블록만 복사하면 된다.
> 이 문서는 설계 의도·게임 내 연출 근거를 담은 한국어 원본이다.

> 클래스별 궁극기(베테랑·헌터·엔지니어)의 발동 사운드를 임팩트 있게 교체하기 위한
> AI 사운드 생성(ElevenLabs SFX, Stable Audio 등) 프롬프트 세트.
> 아이콘과 마찬가지로 **한 번에 같은 모델·같은 설정**으로 뽑아 3종의 톤을 맞춘다.

## 게임 내 재생 방식 (제작 스펙의 근거)
- 발동 순간 **1회 재생**되는 원샷(one-shot). 루프 아님. (`Ultimate.gd::_activate`)
- 궁극기 지속시간 **3.0초**, 쿨다운 24초 → 사운드는 **약 3.5~4.5초**(지속 3초 + 자연 감쇠 테일)가 이상적.
- 재생 볼륨은 SoundManager에 **-3dB**로 이미 세팅되어 있고 피치 변주 ±4%만 걸린다 → 파일 자체를 충분히 크게(피크 -1dBFS, 대략 -14 LUFS) 뽑아야 BGM(-22dB) 위에서 뚫고 나온다.
- 발동과 동시에 화면 셰이크(9.0)와 대형 버스트 FX가 터진다 → **첫 0.1초 안에 강한 어택**이 있어야 화면 연출과 붙는다. 앞부분 무음 패딩 금지.

## 공통 제작 설정
- **파일:** 44.1kHz, 스테레오, OGG Vorbis. 생성 결과가 WAV/MP3면 변환:
  `ffmpeg -i in.wav -c:a libvorbis -q:a 6 assets/audio/sfx_ult_quake.ogg`
- **교체 경로:** `assets/audio/sfx_ult_quake.ogg` / `sfx_ult_arrow.ogg` / `sfx_ult_orbital.ogg`
  — 같은 이름으로 덮어쓰면 코드 수정 없이 즉시 적용된다(SoundManager가 경로로 자동 로드).
- **길이:** 3.5~4.5초. 3초 시점까지는 에너지가 유지되고 이후 자연 감쇠.
- **구조(3종 공통):** `임팩트 어택(0~0.3s) → 지속 텍스처(0.3~3.0s) → 감쇠 테일(3.0s~)`

## 공통 스타일 베이스 (모든 프롬프트 뒤에 붙이기)
```
cinematic video game ultimate ability sound effect, powerful punchy attack
transient at the very start, sustained energy for 3 seconds then a natural
decaying tail, huge and impactful, wide stereo, clean professional game audio,
no music, no melody, no voice, no silence at the beginning
```

## 네거티브 프롬프트 (지원되는 툴에서 공통)
```
music, melody, singing, voice, speech, silence, fade-in intro, low volume,
thin, weak, lo-fi, distorted clipping, abrupt cut-off ending
```

---

## 1) 베테랑 — Seismic Wrath (`sfx_ult_quake.ogg`)
> 연출: 대지가 갈라지는 방사형 균열 + 화면 밖으로 퍼지는 충격 링, 3초 내내 잔진동.
> 방향성: **낮고 무거운 대지의 분노.** 서브베이스가 몸으로 느껴지는 소리.

```
massive earthquake ultimate attack: a deep seismic slam impact with heavy
sub-bass drop at the start, then the ground violently cracking and splitting
open, boulders grinding, continuous low rumbling tremor with periodic rocky
crack bursts, debris and dust falling, ending in a fading underground rumble
```
- 포인트: 0.3초마다 피해 틱 + 지속 셰이크(3.5)가 있으므로, 지속부에 **불규칙한 균열 크랙**이 몇 번 더 터지면 화면과 잘 붙는다.
- 피해야 할 것: 폭발(explosion) 위주로 뽑히면 샷건 `boom`과 구분이 안 됨 — 프롬프트에 `no explosion fireball` 추가 권장.
- ⚠️ **저역만 있으면 안 들린다.** 생성본은 에너지의 99.4%가 200Hz 이하로 나와, 폰 스피커가
  그 대역을 재생하지 못해 "소리가 안 난다"는 말이 나왔다(체감이 다른 궁극기보다 17~20dB 낮았다).
  저역을 키우는 건 답이 아니다 — 기기가 그 대역 자체를 못 낸다. 프롬프트에
  `audible rocky cracking and debris in the midrange, not only sub-bass` 를 넣어 뽑고,
  그래도 저역 덩어리로 나오면 `tools/gen_sfx.py ult_quake` 로 보정한다(아래).

### 현재 적용본 — 저역 보정(`tools/gen_sfx.py ult_quake`)
원본 저역은 살리되 **들리는 성분**을 얹는다.
1. **배음 생성(익사이터)** — 저역을 비선형에 통과시켜 2·3배음을 만들고 150~900Hz 로 걸러 섞는다.
   귀는 배음만으로 원래의 낮은 음을 인지하므로(결여 기본음) 작은 스피커에서도 우르릉이 살아난다.
2. **암석 파열** — 화면의 방사형 균열·충격 링과 0.3초 피해 틱 리듬에 맞춰 갈라지는 소리를 얹는다.
3. 저역 비중을 42% 로 낮춘다 — 어차피 못 내는 대역이 RMS 예산을 다 먹으면 들리는 대역이 조용해진다.

| | 기존 | 현재 | 궤도 폭격(기준) |
|---|---|---|---|
| A-가중 체감 | -39.8dB | **-22.9dB** | -23.1dB |
| 폰 스피커 체감 | -40.1dB | **-22.6dB** | -21.4dB |
| 200Hz 이하 | 99.4% | 37.4% | 62.6% |
| 200~800Hz | 0.6% | **60.9%** | 12.2% |

## 2) 헌터 — Arrow Tempest (`sfx_ult_arrow.ogg`)
> 연출: 하늘에서 화살 42발이 쉼 없이 쏟아져 땅에 콱콱 꽂힘(개별 낙하 주기 0.42~0.67초).
> 방향성: **날카롭고 시원한 폭우.** 공기를 찢는 고음 휘파람 + 촘촘한 타격감.

> ⚠️ 생성기가 "화살이 날아와 꽂힌다"는 서사를 주면 **화살 한 발**로 뽑기 쉽다.
> 그래서 아래 프롬프트는 사건이 아니라 **연속 텍스처**로 기술한다 — 수량을 앞세우고,
> 우박·장대비 같은 밀도 비유를 쓰고, 초당 타격 횟수를 명시하고, 단발을 명시적으로 금지.

```
dense medieval arrow volley barrage: hundreds of arrows falling continuously
like a violent hailstorm, a thick layered wall of overlapping high-pitched
arrow whistles and rapid wooden thunk impacts hitting the ground, eight to
ten impacts every second with no gaps and no pauses, chaotic and relentless
for the entire duration, never a single isolated arrow, massed archery
battlefield texture
```
- 네거티브에 추가: `single arrow, one impact, sparse, slow`
- 그래도 단발로 나오면 문장 첫머리를 `heavy rain of arrows, like hail hammering
  a wooden roof,`로 바꿔 재시도 — "비/우박" 비유가 밀도를 가장 잘 끌어낸다.
- 저음이 부족하면 `deep bow release thump at the start`를 덧붙여 재생성.

### 현재 적용본 — 실제 녹음 + 레이어링(`tools/make_arrow_rain.py`)
AI 에 "화살비" 전체를 시키면 밀도가 부족해 유리 깨지는 소리가 되고, 화살 한 발을
**절차적으로 합성**해 겹치면 이번엔 벌떼처럼 웅웅거렸다(감쇠 정현파 몸통이 악기음처럼
들린다). 결국 **화살 한 발만 실제로 생성**하고, 겹치는 일은 스크립트가 하는 방식이 맞았다.
생성기는 단발은 잘 만들고, 밀도·길이·좌우 배치는 코드가 정확히 통제할 수 있다.

```bash
python3 tools/make_arrow_rain.py --src arrow.mp4   # → assets/audio/sfx_ult_arrow.ogg
python3 tools/make_arrow_rain.py                   # 소스 없이 절차적 합성(폴백)
```

한 파일에 테이크가 여러 개 들어있으면 **전부 찾아내 변주로 쓴다**(이번 소스는 5종).
화살마다 꽂히는 소리가 달라져 같은 소리의 반복으로 들리지 않는다. 가장 큰 테이크보다
12dB 이상 작은 조각은 잔향·잡음으로 보고 버린다.

**핵심 지표는 "동시에 몇 발이 울리는가"** = 화살 길이 × 발수 ÷ 전체 길이. 3을 넘으면
타격이 서로 메워져 잡음 덩어리가 된다. 생성음 한 발은 잔향까지 0.4~0.6초라 그대로 쓰면
겹침이 6을 넘어가므로, 0.22초로 잘라 쓰고(`MAX_ARROW`) 발수로 최종 조정한다.

**길이는 연출에 맞춘다** — 궁극기 지속은 3.0초(`area_duration`)다. 사운드가 더 길면
화면에는 아무것도 없는데 화살만 계속 떨어져 어긋난다. 3.25초(3.0초 + 짧은 여운)로 맞췄다.

| | 값 | 비고 |
|---|---|---|
| 길이 | 3.25초 | 연출 3.0초 + 여운 |
| 화살 길이 / 발수 | 0.22초 / 36발 | 동시 겹침 2.4개 |
| 타격 밀도 | 9.5회/초 | 프롬프트 목표 8~10 |
| 피크-중앙 | 17.0dB | 타격 사이가 조용해 하나하나 들린다 |
| 온셋 | 0ms | 발동 셰이크와 동기 |

배치는 층화(구간을 발수만큼 나눠 한 칸에 하나) — 무작위로 뿌리면 뭉치고 비는 구간이
생겨 "쉼 없이 쏟아진다"가 깨진다. 도입부 몇 발은 시작을 음수로 둬 발동 즉시 타격이 꽂힌다.

### 화살 한 발 생성 프롬프트 (재생성이 필요할 때)
```
Single arrow shot into dirt: one quick sharp whoosh as the arrow cuts through
air, then a deep solid thud as the arrowhead buries into packed earth, with a
brief wooden shaft wobble and a little scattered soil, dry and close, no reverb,
no echo. Realistic, clean 2D game sound effect, no music, no voice, no silence
at the beginning.
```
한 번에 여러 테이크가 나와도 좋다 — 많을수록 변주가 풍부해진다.

## 3) 엔지니어 — Orbital Barrage (`sfx_ult_orbital.ogg`)
> 연출: 0.35초마다 자리를 옮기며 하늘에서 수직 광선 5기가 꽂힘(3초간 약 8세트).
> 방향성: **차갑고 압도적인 기계 병기.** 충전 → 반복 타격의 리듬이 핵심.

```
orbital laser strike ultimate attack: a quick sci-fi targeting charge-up hum,
then repeated powerful energy beams firing down from the sky in rapid rhythm,
each beam a searing electric zap followed by a plasma impact explosion on the
ground, roughly three strikes per second layered and overlapping, ending with
a discharging electrical fizzle
```
- 포인트: 광선 세트가 **초당 약 3회** 리듬으로 꽂히므로 `roughly three strikes per second`를 유지 — 리듬이 화면과 동기화된 느낌을 준다.
- 톤이 `laser`(플라스마 무기음)와 겹치면 `deeper and heavier than a handheld laser, satellite-scale weapon`을 추가.

---

## 짧은 프롬프트 버전 (ElevenLabs SFX 등 단문 입력 툴용)
| id | 프롬프트 |
|---|---|
| ult_quake | `massive earthquake slam, deep sub-bass rumble, ground cracking apart, 4 seconds, game ultimate SFX` |
| ult_arrow | `hundreds of arrows falling like a hailstorm, continuous overlapping whistles and rapid wooden thunk impacts, no gaps, never a single arrow, 4 seconds, game ultimate SFX` |
| ult_orbital | `sci-fi orbital laser bombardment, charge-up then repeated energy beam strikes, 4 seconds, game ultimate SFX` |

## 후처리 체크리스트
1. 앞부분 무음 트리밍(어택이 0초에 바로 시작하는지).
2. 3종 모두 같은 라우드니스로 노멀라이즈(-14 LUFS 근처, 피크 -1dBFS):
   `ffmpeg -i in.wav -af loudnorm=I=-14:TP=-1 -c:a libvorbis -q:a 6 out.ogg`
3. 끝부분이 뚝 끊기지 않는지(테일 자연 감쇠 확인, 필요 시 100ms 페이드아웃).
4. 게임에서 확인: BGM 위에서 존재감이 있는지, 샷건 `boom`·`laser`와 헷갈리지 않는지,
   3종을 연달아 들었을 때 클래스 개성이 구분되는지.

---

# 신규 효과음 프롬프트 (연출 대비 사운드 공백 보완)

> 코드에는 재생 호출이 이미 들어가 있고, 아래 파일명으로 `assets/audio/` 에 넣는 순간
> 자동 적용된다(파일이 없으면 조용히 생략 — SoundManager 선택 사운드 패턴).
> 궁극기와 달리 **짧은 원샷**이므로 길이·톤 기준이 다르다.

## 공통 스타일 베이스 (아래 프롬프트 뒤에 붙이기)
```
retro-modern 2D game sound effect, punchy transient, dry and tight, mono
compatible, clean, no music, no voice, no silence at the beginning
```

| 파일명 | 길이 | 프롬프트 |
|---|---|---|
| `sfx_bomber_blast.ogg` | 0.8~1.2s | `close-range suicide bomber explosion, sharp flesh-and-shrapnel burst with a short punchy low thump, dry and tight, no long reverb tail` |
| `sfx_bomber_fuse.ogg` | 0.5s | `short urgent warning beep sequence, three quick rising electronic ticks like a bomb fuse about to blow, small and dry` |
| `sfx_evolve.ogg` | 1.5~2.5s | `triumphant weapon evolution fanfare, a rising magical power surge that transforms into a bright metallic bloom, heroic and rewarding, short orchestral hit with shimmer` |
| `sfx_wave_clear.ogg` | 0.8~1.2s | `short positive achievement stinger, two or three bright ascending notes with a satisfying finish, clean and crisp, not a long fanfare` |
| `sfx_revive.ogg` | 1.5~2s | `heroic revival sound, a soft holy choir-like chime swelling up with a warm energy surge and a heartbeat resuming, uplifting and dramatic` |
| `sfx_swing.ogg` | 0.25s | `a quick heavy bat swing whoosh cutting through air, short and dry, no impact, no hit` |
| `sfx_holy_splash.ogg` | 0.6~0.9s | `a glass vial shattering on the ground and holy water splashing, bright glass shards with a soft magical shimmer, wet and crisp` |
| `sfx_spit.ogg` | 0.4s | `a wet guttural acid spit projectile launch from a monster, short slimy hawking burst, disgusting and organic` |

## 볼륨 기준 (SoundManager 에 이미 설정됨)
`evolve`/`revive`/`bomber_blast` 는 -4~-5dB로 크게, `swing`(-13) / `spit`(-14) 는
초당 여러 번 울리므로 아주 작게 잡혀 있다. **생성 파일은 전부 같은 라우드니스로
노멀라이즈**하고 세기 조절은 SoundManager 값으로 한다(파일마다 제각각이면 관리 불가).

```bash
ffmpeg -i in.wav -af loudnorm=I=-16:TP=-1 -c:a libvorbis -q:a 6 assets/audio/sfx_swing.ogg
```

## 주의
- `swing`/`spit`/`holy_splash`/`bomber_fuse` 는 **반복 재생**되는 소리다.
  꼬리가 길거나 개성이 강하면 몇 분 만에 귀에 거슬린다 — 짧고 건조하게(`dry`, `short`).
- `bomber_blast` 는 기존 `boom`(샷건/폭발물)과 구분되어야 한다. 파편·살점 느낌을 넣고
  잔향을 줄여 "가까이서 터진 좀비"로 들리게 한다.
- `wave_clear` 는 `victory`(30분 클리어)보다 확실히 가볍고 짧아야 한다 — 웨이브마다 울린다.
