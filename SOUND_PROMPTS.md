# 궁극기 사운드 생성 프롬프트

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

### 플랜 B — 화살 1발을 뽑아 42발로 합성
프롬프트를 어떻게 바꿔도 단일 사운드만 나오면, 반대로 **잘 뽑힌 한 발**을 재료로
쓰는 게 가장 확실하다. 아래 프롬프트로 0.4초짜리 화살 1발을 뽑고:
```
single arrow flyby: one quick sharp whoosh cutting through air then a solid
wooden thunk impact into the ground, short and dry, no reverb tail
```
동봉된 스크립트로 무작위 시차·피치·좌우 팬을 줘 42발을 겹치면 화살비가 된다
(초반 도입 → 절정 → 감쇠 밀도 곡선 포함, 4초 스테레오):
```bash
python3 tools/make_arrow_rain.py one_arrow.wav rain.wav 42 4.0
ffmpeg -i rain.wav -af loudnorm=I=-14:TP=-1 -c:a libvorbis -q:a 6 \
    assets/audio/sfx_ult_arrow.ogg
```

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
