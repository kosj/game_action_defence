# 안드로이드 보상형 광고(AdMob) 연동 가이드

이 문서는 **AdMob 보상형(Rewarded) 광고**를 안드로이드 빌드에 붙이는 절차다.
게임 코드는 이미 광고 자리(“revive”·“shop_gold”)가 배선돼 있고, 실제 SDK 연동은
`scripts/AdManager.gd` 의 `_admob_*` 4개 메서드에만 채우면 되도록 격리해 놓았다.

- **웹·에디터·PC**: `USE_STUB = true` 유지 → SDK 없이 내장 더미 광고로 동작(현행 그대로).
- **안드로이드 실광고 빌드**: 플러그인을 설치하고 `USE_STUB = false` 로 바꾼 뒤 아래 스니펫으로
  `_admob_*` 메서드 본문을 채운다. 호출부(HUD·상점)는 한 줄도 고치지 않는다.

> 플러그인이 **설치돼 있지 않아도** `AdManager.gd` 가 정상 파싱된다. 플러그인 클래스를
> 직접 참조하는 코드가 없기 때문이다. 그래서 웹/에디터 빌드는 애드온 없이도 깨지지 않는다.

---

## 0. 준비물

| 항목 | 내용 |
| --- | --- |
| AdMob 계정 | https://admob.google.com 에서 앱 등록 → **App ID**, **Rewarded 광고단위 ID** 발급 |
| Godot 안드로이드 빌드 | Godot 4.x + Android SDK/JDK, 커스텀 빌드 템플릿 설치 |
| 플러그인 | [poing-studios/godot-admob-android](https://github.com/poing-studios/godot-admob-android) (Godot 4 대응 릴리스) |
| 키스토어 | 릴리스 서명용 `.keystore` (Play 콘솔 업로드/서명) |

개발 중에는 **반드시 구글 공식 테스트 광고**를 쓴다. 실제 광고를 자기 기기에서 반복 노출/클릭하면
정책 위반으로 계정이 정지될 수 있다. → `AdManager.gd` 의 `USE_TEST_ADS = true` 로 유지.

---

## 1. 플러그인 설치

1. poing-studios 릴리스 페이지에서 **Godot 4 대응 버전**의 애드온을 내려받는다.
2. 압축을 풀어 프로젝트에 넣는다:
   ```
   res://addons/admob/            # GDScript 래퍼 + export plugin
   ```
3. Godot 에디터 → **Project → Project Settings → Plugins** 에서 `AdMob` 플러그인을 **Enable**.
4. 에디터를 재시작하면 `MobileAds`, `RewardedAd`, `AdRequest` 등 플러그인 클래스가 인식된다.

> 플러그인 버전에 따라 클래스/콜백 이름이 조금씩 다르다. 아래 스니펫은 “현재 Godot 4 플러그인”
> 기준의 전형적인 형태이며, **애드온에 포함된 데모 씬(`example`/`demo`)의 실제 API 를 최종 기준**
> 으로 삼아 이름을 맞춘다.

---

## 2. 안드로이드 익스포트 설정

### 2-1. 커스텀 빌드 템플릿

- **Project → Install Android Build Template** 실행 → `res://android/build/` 생성.
- **Project → Export → Android** 프리셋에서 **Use Gradle Build** 체크(플러그인이 Gradle 의존성을
  주입하므로 필수).

### 2-2. AndroidManifest — 필수 항목 2개

플러그인은 export 시 매니페스트를 병합하지만, 아래 두 값은 반드시 들어가야 한다.
export 프리셋의 커스텀 매니페스트나 `res://android/build/AndroidManifest.xml` 에서 확인한다.

```xml
<!-- 1) 광고 식별자 권한 (Android 13+) -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>

<!-- 2) AdMob App ID meta-data — 이 값이 없으면 앱이 실행 즉시 크래시한다.
        AdManager.admob_app_id() 가 돌려주는 값과 반드시 동일해야 한다. -->
<application ...>
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-3940256099942544~3347511713"/>  <!-- 테스트 App ID -->
</application>
```

> poing-studios 플러그인은 보통 export 프리셋에 **AdMob App ID 입력란**을 제공한다. 거기에 넣으면
> 매니페스트에 자동 병합된다. 그 값도 `AdManager` 의 App ID 와 **한 글자도 다르면 안 된다.**

### 2-3. 키스토어

Play 출시는 서명이 필요하다. export 프리셋의 **Release** 항목에 릴리스 키스토어/별칭/비밀번호를 지정한다.
(키스토어 파일과 비밀번호는 **저장소에 커밋하지 않는다** — CI 라면 secret 로 주입.)

---

## 3. `AdManager.gd` 의 `_admob_*` 채우기

플러그인을 설치했다면 아래처럼 **플러그인 인스턴스를 담을 변수**를 추가하고 4개 메서드 본문을
채운다. 지켜야 할 계약은 파일 주석에도 적어 두었다:

- 보상 획득 → `_grant(placement)` · 닫힘/노출 실패 → `_dismiss(placement)`
- 로드 완료 시 `_rewarded_loaded = true`
- 노출/실패 뒤에는 `_admob_load_rewarded()` 로 재로드(광고는 1회용) — 이건 `_finish()` 가 이미 호출한다
- 두 종료 콜백은 `CONNECT_ONE_SHOT` 성격(중복 지급/닫힘 방지)

```gdscript
# ── 파일 상단 상태 변수 옆에 추가 ──
var _rewarded: RewardedAd = null      # 플러그인 설치 후에만 유효한 타입


func _admob_init() -> void:
    MobileAds.initialize()
    # UMP(사용자 동의) — 4장 참고. 동의가 확정되면 아래를 실행한다.
    _consent_ok = true
    _admob_load_rewarded()


func _admob_load_rewarded() -> void:
    var cb := RewardedAdLoadCallback.new()
    cb.on_ad_loaded = func(ad: RewardedAd) -> void:
        _rewarded = ad
        _rewarded_loaded = true
    cb.on_ad_failed_to_load = func(_err) -> void:
        _rewarded = null
        _rewarded_loaded = false
    RewardedAd.load(rewarded_unit_id(), AdRequest.new(), cb)


func _admob_is_loaded() -> bool:
    return _rewarded_loaded and _rewarded != null


func _admob_show_rewarded(placement: String) -> void:
    # 전체화면 콜백: 닫히거나 노출 실패하면 보상 없이 종료.
    var fs := FullScreenContentCallback.new()
    fs.on_ad_dismissed_full_screen_content = func() -> void:
        _dismiss(placement)     # 보상을 못 받고 닫은 경우
    fs.on_ad_failed_to_show_full_screen_content = func(_err) -> void:
        _dismiss(placement)
    _rewarded.full_screen_content_callback = fs

    # 보상 지급 리스너: 끝까지 시청 시 1회 호출.
    var reward := OnUserEarnedRewardListener.new()
    reward.on_user_earned_reward = func(_item) -> void:
        _grant(placement)       # ← 여기서만 보상 지급

    _rewarded.show(reward)
    _rewarded = null            # 사용한 인스턴스는 버린다(재로드는 _finish() 가 처리)
```

> **주의 — 지급/닫힘 중복.** AdMob 은 “보상 지급(user_earned_reward)” 콜백과 “닫힘(dismissed)”
> 콜백이 **둘 다** 불린다(끝까지 본 경우: earned → dismissed 순). 위 코드는 `_grant` 와 `_dismiss`
> 가 각각 한 번씩 불릴 수 있는데, `_grant`/`_dismiss` 모두 `_finish()` 로 `_busy` 를 내리고
> 시그널을 쏘므로 **보상이 두 번 지급되는 문제가 생길 수 있다.** 반드시 아래 중 하나로 가드한다:
> - 지급되면 플래그를 세우고 dismissed 에서는 “이미 지급됐으면 아무 것도 안 함”:
>   ```gdscript
>   var _earned := false
>   reward.on_user_earned_reward = func(_i): _earned = true; _grant(placement)
>   fs.on_ad_dismissed_full_screen_content = func():
>       if not _earned: _dismiss(placement)
>   ```
>   (`show` 직전에 `_earned = false` 초기화)

### 플래그를 세우는 방식(권장 최종형)

```gdscript
func _admob_show_rewarded(placement: String) -> void:
    var earned := [false]     # 클로저 캡처용(배열로 참조 캡처)

    var fs := FullScreenContentCallback.new()
    fs.on_ad_dismissed_full_screen_content = func() -> void:
        if not earned[0]:
            _dismiss(placement)
    fs.on_ad_failed_to_show_full_screen_content = func(_err) -> void:
        _dismiss(placement)
    _rewarded.full_screen_content_callback = fs

    var reward := OnUserEarnedRewardListener.new()
    reward.on_user_earned_reward = func(_item) -> void:
        earned[0] = true
        _grant(placement)

    _rewarded.show(reward)
    _rewarded = null
```

---

## 4. UMP(사용자 동의) — EEA/UK 필수, 그 외 권장

유럽 등지에서는 광고 개인화 동의를 UMP(User Messaging Platform)로 받아야 한다. 미구현이면
해당 지역에서 광고가 안 나오거나 정책 위반이 된다. `_admob_init()` 안에서 초기화 전/후에 처리한다.

```gdscript
func _admob_init() -> void:
    # 1) 동의 정보 갱신 → 필요 시 동의 폼 로드/표시
    var params := ConsentRequestParameters.new()
    # 테스트 지역 강제: 개발 중 EEA 로 시뮬레이션하려면 debug settings 지정(플러그인 데모 참고)
    ConsentInformation.request_consent_info_update(
        params,
        func() -> void:                       # on_update_success
            if ConsentInformation.is_consent_form_available():
                _load_and_show_consent_form()
            else:
                _after_consent(),
        func(_err) -> void:                   # on_update_failure
            _after_consent())                 # 실패해도 진행(비개인화 광고로 폴백)


func _load_and_show_consent_form() -> void:
    ConsentForm.load(
        func(form) -> void:
            form.show(func(_err) -> void: _after_consent()),
        func(_err) -> void: _after_consent())


func _after_consent() -> void:
    _consent_ok = true
    MobileAds.initialize()
    _admob_load_rewarded()
```

> 클래스/메서드 이름(`ConsentInformation`, `ConsentForm`, `ConsentRequestParameters`)은 플러그인
> 버전마다 다를 수 있다. **플러그인 데모의 UMP 예제**를 기준으로 맞춘다. 동의 절차가 끝나기 전에는
> `is_rewarded_ready()` 가 `false`(코드에서 `_consent_ok and _admob_is_loaded()`)라 광고가 뜨지 않는다.

---

## 5. app-ads.txt (권장)

광고 수익 보호(사칭 인벤토리 차단)를 위해 앱의 “마케팅 URL” 도메인 루트에 `app-ads.txt` 를 올린다.
이 프로젝트는 GitHub Pages(`kosj.github.io`)를 쓰므로, 그 사이트 루트에 아래 형식으로 배치한다.

```
google.com, pub-0000000000000000, DIRECT, f08c47fec0942fa0
```

- `pub-0000...` 는 내 **AdMob 게시자 ID**(App ID 의 `~` 앞부분에서 `ca-app-pub-` 제외한 숫자).
- Play 콘솔의 앱 “웹사이트” 필드에 이 도메인을 등록해야 AdMob 이 매칭한다.
- 반영에는 시간이 걸리며 AdMob → **앱 → app-ads.txt** 에서 상태를 확인한다.

---

## 6. Play 콘솔 — 데이터 보안(Data Safety)

AdMob 은 광고 식별자·기기 정보를 수집하므로 **Data Safety** 설문에 정확히 반영해야 심사를 통과한다.

- **수집/공유 데이터**: “기기 또는 기타 식별자(Device or other IDs)” = 수집·공유(광고 목적).
- **목적**: 광고 또는 마케팅(Advertising or marketing), 분석(Analytics).
- **AD_ID 권한**: 위 2-2 에서 넣은 `AD_ID` 권한을 콘솔이 감지 → 설문과 일치해야 함.
- 개인정보 처리방침 URL 필수(광고/식별자 수집 명시).

세부 항목은 Google 의 “AdMob 과 Data safety” 문서를 최종 기준으로 삼는다.

---

## 7. 실광고로 전환 체크리스트

`scripts/AdManager.gd` 상단 상수만 바꾸면 코드 전환은 끝이다.

```gdscript
const USE_STUB := false          # 안드로이드 실광고 빌드
const USE_TEST_ADS := false      # 최종 출시. (심사 전까지는 true 로 테스트 광고 유지)
const ADMOB_APP_ID_REAL := "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"
const REWARDED_UNIT_REAL := "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"
```

| 단계 | 확인 |
| --- | --- |
| 1 | 플러그인 설치·활성화, 데모 씬 API 로 `_admob_*` 4개 채움 |
| 2 | AndroidManifest 에 `AD_ID` 권한 + `APPLICATION_ID` meta-data(=`admob_app_id()`) |
| 3 | `USE_STUB=false`, **`USE_TEST_ADS=true`** 로 실기기 테스트 광고 노출 확인(revive/shop_gold 둘 다) |
| 4 | 지급/닫힘 가드(3장) 검증 — 끝까지 시청 시 보상 1회만, 중도 닫으면 0회 |
| 5 | UMP 동의 흐름 확인(EEA 시뮬레이션) |
| 6 | app-ads.txt 게시 + Play 데이터 보안 설문 |
| 7 | 실 ID 입력, `USE_TEST_ADS=false`, 서명 빌드 업로드 |

---

## 부록. 관련 코드 위치

- `scripts/AdManager.gd` — 광고 매니저(스텁/실연동 어댑터). **여기만 손대면 됨.**
- `scripts/HUD.gd` — “revive”(부활) 보상 광고 호출 (`AdManager.show_rewarded("revive")`).
- `scripts/ShopPanel.gd` — “shop_gold”(골드 보상) 호출.
- `USE_STUB=true` 인 동안 웹/에디터는 내장 더미 오버레이로 흐름을 그대로 시연할 수 있다.
