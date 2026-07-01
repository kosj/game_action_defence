# 랭킹 · 클라우드 저장 연동 가이드 (Google Play Games Services)

이 문서는 **모드별 최고 점수 랭킹**을 안드로이드 빌드에 붙이는 절차다.
게임 코드는 이미 **플랫폼 독립 인터페이스**로 설계돼 있어, 웹/에디터/PC 는 로컬 최고점으로
그대로 동작하고 안드로이드에서만 Google Play 리더보드가 켜진다.

- **웹·에디터·PC**: `LocalRankingBackend` — `user://ranking.json` 에 모드별 최고점 저장(현행 동작).
- **안드로이드 실빌드**: 플러그인 설치 + `RankingManager.USE_PLAY_GAMES = true` → `PlayGamesRankingBackend`
  가 로컬에 미러링하면서 온라인 리더보드에 제출/조회.

> `PlayGamesRankingBackend` 는 **플러그인 클래스를 직접 참조하지 않으므로** addon 미설치 상태에서도
> 스크립트가 정상 파싱된다(AdMob 스캐폴드와 동일한 방식). 웹/에디터 빌드가 깨지지 않는다.

---

## 0. 설계 개요 — 인터페이스 구조

```
RankingManager (Autoload, 파사드)
    └─ _backend : RankingBackend        ← 게임 코드는 이 파사드만 호출
         ├─ LocalRankingBackend         (웹/PC/에디터, 그리고 온라인 백엔드의 오프라인 캐시)
         └─ PlayGamesRankingBackend     (안드로이드; Local 을 상속 → 로컬 미러 + PGS 리더보드)
```

**호출부(메뉴·HUD)는 `RankingManager` 만 안다.** 새 플랫폼(예: iOS Game Center, Firebase)을 붙이려면
`RankingBackend` 를 상속한 백엔드를 하나 만들고 `RankingManager._make_backend()` 에서 골라주면 끝이다.
게임 로직은 한 줄도 바뀌지 않는다.

**모드 = 난이도.** `MODES = ["easy","normal","hard"]` 이고 각 모드가 **독립된 최고점**(과 온라인
리더보드)을 가진다. 난이도를 바꾸면 메뉴의 "최고 점수" 표시와 게임오버 신기록 판정 기준이 그
모드의 값으로 바뀐다.

### 공개 API (RankingManager)

| 메서드 | 설명 |
| --- | --- |
| `current_mode_id()` (static) | 현재 난이도의 모드 id |
| `current_best()` / `best_for_mode(id)` | 최고점 조회 |
| `all_bests()` | `{easy,normal,hard: int}` — 랭킹 화면용 |
| `submit(score, mode_id="")` | 점수 제출(로컬 갱신 + 온라인) — 게임오버 시 자동 호출됨 |
| `show_leaderboard(mode_id="")` | 네이티브 리더보드 열기(온라인만) |
| `is_online()` / `is_signed_in()` | 백엔드 종류/로그인 상태 |

게임오버(`Events.player_died`)와 실시간 신기록(`Events.high_score_changed`)에 이미 연결돼 있어
**호출부에서 별도 제출 코드가 필요 없다.**

---

## 1. 준비물

| 항목 | 내용 |
| --- | --- |
| Google Play Console | 앱 등록 + **Play Games Services** 구성 |
| Google Cloud 프로젝트 | OAuth 2.0 클라이언트(안드로이드) — Play Console 이 안내 |
| 플러그인 | [Iakobs/godot-play-game-services](https://github.com/Iakobs/godot-play-game-services) (Godot 4 대응) |
| 서명 키 | 업로드/앱서명 키의 **SHA-1** 지문(OAuth 등록에 필요) |

---

## 2. Play Console — 리더보드 3개 생성

1. Play Console → 앱 → **Play Games Services → 설정 및 관리 → 구성**. 이름/OAuth 동의 화면 등을 채운다.
2. **리더보드(Leaderboards)** 에서 모드별로 **3개** 생성:
   - `DeadLine — Easy`, `DeadLine — Normal`, `DeadLine — Hard`
   - 정렬: **높은 값이 상위(Larger is better)**, 형식: 정수(점수).
3. 각 리더보드의 **ID**(형식 예: `CgkI abcd...`) 를 복사해 `scripts/RankingManager.gd` 에 채운다:
   ```gdscript
   const LEADERBOARD_IDS := {
       "easy":   "CgkI...EASY",
       "normal": "CgkI...NORMAL",
       "hard":   "CgkI...HARD",
   }
   ```
4. **테스터 등록**: 구성 → 테스터에 본인 계정을 넣어야 심사 전에도 로그인/제출이 된다.
5. OAuth 클라이언트에 **서명 키 SHA-1** 을 등록(업로드 키 + Play 앱서명 키 둘 다 권장).

---

## 3. 플러그인 설치

1. 릴리스에서 Godot 4 대응 애드온을 받아 `res://addons/` 에 넣는다.
2. **Project → Project Settings → Plugins** 에서 활성화 후 에디터 재시작.
3. 안드로이드 익스포트: **Install Android Build Template** + export 프리셋 **Use Gradle Build** 체크.
4. AndroidManifest 에 **Games App ID** meta-data 가 들어가야 한다(플러그인이 export 설정으로 주입).
   Play Console 의 게임 프로젝트 번호(App ID)를 프리셋 입력란에 넣는다.
   ```xml
   <meta-data android:name="com.google.android.gms.games.APP_ID"
              android:value="@string/game_services_project_id"/>
   ```

> 플러그인 버전마다 싱글톤/시그널 이름이 다를 수 있다. 아래 스니펫은 Iakobs 플러그인 기준의
> 전형적 형태이며, **애드온 데모 씬의 실제 API 를 최종 기준**으로 이름을 맞춘다.

---

## 4. `PlayGamesRankingBackend` 의 `_pgs_*` 채우기

`scripts/ranking/PlayGamesRankingBackend.gd` 의 3개 어댑터만 채우면 된다.
계약: **로그인 성공/실패 시 반드시 `_set_signed_in(true/false)` 호출.**

```gdscript
func _pgs_sign_in() -> void:
    PlayGamesSDK.initialize()
    # 로그인 상태 시그널 연결 (한 번만)
    if not SignInClient.user_authenticated.is_connected(_on_pgs_auth):
        SignInClient.user_authenticated.connect(_on_pgs_auth)
    SignInClient.is_authenticated()   # 자동 로그인 시도 → 결과가 user_authenticated 로 온다


func _on_pgs_auth(is_authenticated: bool) -> void:
    _set_signed_in(is_authenticated)   # 부모의 헬퍼: 상태 저장 + sign_in_changed emit


func _pgs_submit_score(leaderboard_id: String, score: int) -> void:
    LeaderboardsClient.submit_score(leaderboard_id, score)


func _pgs_show_leaderboard(leaderboard_id: String) -> bool:
    LeaderboardsClient.show_leaderboard(leaderboard_id)
    return true
```

> `_on_pgs_auth` 는 새 메서드다 — 파일에 함께 추가한다. 시그널 이름
> (`user_authenticated`)·메서드(`is_authenticated`, `submit_score`, `show_leaderboard`)는
> 플러그인 데모를 기준으로 확인할 것.

로컬 미러링·모드별 최고점·게임오버 제출은 부모(`LocalRankingBackend`)와 `RankingManager` 가
이미 처리하므로 위 3개 외에는 손댈 것이 없다.

---

## 5. 실랭킹으로 전환

`scripts/RankingManager.gd` 상단만 바꾼다.

```gdscript
const USE_PLAY_GAMES := true                 # 안드로이드에서 PGS 사용
const LEADERBOARD_IDS := { "easy": "CgkI...", "normal": "CgkI...", "hard": "CgkI..." }
```

`_make_backend()` 는 `USE_PLAY_GAMES and OS.get_name() == "Android"` 일 때만 PGS 백엔드를 쓰므로,
**웹/PC/에디터는 자동으로 로컬**로 남는다(플래그를 켜도 안전).

| 단계 | 확인 |
| --- | --- |
| 1 | Play Console 리더보드 3개 생성 + ID 를 `LEADERBOARD_IDS` 에 입력 |
| 2 | OAuth 에 서명 키 SHA-1 등록, 테스터 계정 추가 |
| 3 | 플러그인 설치·활성화, `_pgs_*` 3개(+`_on_pgs_auth`) 구현 |
| 4 | `USE_PLAY_GAMES = true`, 서명 빌드로 실기기 로그인 확인 |
| 5 | 게임오버 후 각 난이도 리더보드에 점수가 오르는지 확인 |
| 6 | 메인메뉴 → 랭킹 → "Google Play 랭킹 보기" 로 네이티브 UI 표시 확인 |

---

## 6. 데이터 저장(클라우드 세이브)로 확장하려면

같은 인터페이스 패턴을 저장에도 적용할 수 있다. PGS 의 **Saved Games(Snapshots)** 를 쓰면
현재 `SaveManager` 의 체크포인트(골드/업그레이드/무기)를 기기 간 동기화할 수 있다.

권장 방법: `SaveBackend` 인터페이스(로컬/PGS-Snapshots)를 `RankingBackend` 와 동일한 구조로 만들고
`SaveManager` 가 그 백엔드에 위임하게 리팩터. 로컬을 진실 원본(source of truth)으로 두고 로그인 시
Snapshot 과 병합(더 큰 진행도 우선)하면 오프라인에서도 안전하다. (이번 변경 범위 밖 — 필요 시 별도 작업.)

---

## 7. 다른 플랫폼(iOS / 통합 백엔드)

- **iOS**: `GameCenterRankingBackend extends RankingBackend` 를 만들고 GameKit 리더보드에 매핑.
- **웹 포함 통합 랭킹**: `FirebaseRankingBackend` 로 Firestore 컬렉션(모드별 문서)에 제출/조회.
- 어느 경우든 `RankingManager._make_backend()` 의 분기만 추가하면 되고, 메뉴/HUD/게임오버 코드는
  그대로다.

---

## 부록. 관련 코드 위치

- `scripts/RankingManager.gd` — 파사드(Autoload). 모드 정의·리더보드 ID·백엔드 선택. **주로 여기.**
- `scripts/ranking/RankingBackend.gd` — 백엔드 인터페이스(신규 플랫폼은 이걸 상속).
- `scripts/ranking/LocalRankingBackend.gd` — 로컬 저장(웹/PC/에디터, 오프라인 캐시).
- `scripts/ranking/PlayGamesRankingBackend.gd` — 안드로이드 PGS 어댑터(`_pgs_*` 채우는 곳).
- `scripts/MainMenu.gd` — "랭킹" 버튼 + 모드별 최고점 오버레이(온라인 시 네이티브 리더보드 버튼).
- `scripts/SaveManager.gd` — 구버전 단일 최고점을 모드별로 1회 이관(`read_legacy_high_score`).
