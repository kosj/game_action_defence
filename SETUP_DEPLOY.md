# 별도 저장소로 웹 배포하기 (Deploy Key)

소스는 **`kosj/game_action_defence`** 에서 작업하고, 빌드된 WebGL 은 **`kosj/game_action_defence_deploy`**
저장소의 `gh-pages` 브랜치로 배포한다. 그 저장소의 GitHub Pages 가 게임을 서빙한다.

```
game_action_defence (소스)
   └─ push to main → GitHub Actions → Godot WebGL 빌드
                          └─ (Deploy Key 로) game_action_defence_deploy 의 gh-pages 로 push
                                   └─ GitHub Pages 서빙: https://kosj.github.io/game_action_defence_deploy/
```

워크플로(`.github/workflows/export-web.yml`)는 이미 이 방식으로 수정돼 있다.
아래 **1회성 설정**만 GitHub UI 에서 직접 해주면 된다(워크플로의 다른 저장소 push 는
기본 GITHUB_TOKEN 으로 안 되고 별도 인증이 필요하기 때문).

---

## 1. 배포 저장소 생성

- `kosj/game_action_defence_deploy` 저장소를 만든다. (없다면)
- **Public** 이어야 무료 GitHub Pages 를 쓸 수 있다.
- 비워둬도 된다. 첫 배포 때 `gh-pages` 브랜치가 자동 생성된다.

## 2. Deploy Key(SSH 키쌍) 생성

로컬에서 (커밋하지 말 것):

```bash
ssh-keygen -t ed25519 -C "game_action_defence deploy" -f deploy_key -N ""
# → deploy_key (개인키), deploy_key.pub (공개키) 두 파일 생성
```

## 3. 공개키 → 배포 저장소에 등록

`game_action_defence_deploy` → **Settings → Deploy keys → Add deploy key**
- Title: `CI deploy` (아무 이름)
- Key: `deploy_key.pub` 파일 내용 전체 붙여넣기
- ✅ **Allow write access** 반드시 체크

## 4. 개인키 → 소스 저장소에 시크릿으로 등록

`game_action_defence` → **Settings → Secrets and variables → Actions → New repository secret**
- Name: `DEPLOY_KEY`  (워크플로가 참조하는 이름과 정확히 일치해야 함)
- Secret: `deploy_key`(개인키) 파일 내용 전체 (`-----BEGIN ...` 부터 `... END-----` 까지)

> 등록 후 로컬의 `deploy_key` / `deploy_key.pub` 파일은 삭제해도 된다.

## 5. 배포 저장소의 Pages 켜기

`game_action_defence_deploy` → **Settings → Pages**
- Source: **Deploy from a branch**
- Branch: **`gh-pages`** / **`/ (root)`** → Save
- (첫 배포가 gh-pages 를 만든 "다음"에 이 옵션이 보인다. 배포를 먼저 한 번 돌리고 설정해도 됨.)

## 6. 배포 실행

- 소스 저장소 `main` 에 push 하면 자동으로 빌드+배포된다.
- 수동 실행: Actions → **Export Web (Godot 4)** → **Run workflow**.
- 완료 후 몇 분 뒤 `https://kosj.github.io/game_action_defence_deploy/` 에서 확인.

---

## 참고 / 마이그레이션

- **기존 소스 저장소 Pages**: 이제 배포에 쓰이지 않는다. `game_action_defence` → Settings → Pages
  에서 꺼두거나 그대로 둬도 무방(더 이상 갱신되지 않음).
- **경로 문제 없음**: Godot 웹 export 는 상대경로라 `/game_action_defence_deploy/` 하위 경로에서도
  그대로 동작한다. 별도 base href 설정 불필요.
- **커스텀 도메인**: 배포 저장소 Pages 설정에 도메인을 넣고, 워크플로 `publish_dir` 에 `CNAME` 를
  포함하거나 peaceiris 의 `cname:` 옵션을 추가하면 된다.
- **루트 도메인(kosj.github.io)으로 서빙하고 싶다면**: 배포 저장소 이름을 `kosj.github.io` 로 만들고
  워크플로의 `external_repository` 를 그에 맞게 바꾼다(그 경우 URL 은 `https://kosj.github.io/`).

## 트러블슈팅

| 증상 | 원인/해결 |
| --- | --- |
| `Permission denied (publickey)` | 공개키의 **Allow write access** 미체크, 또는 DEPLOY_KEY 개인키 불일치 |
| `DEPLOY_KEY` 관련 빈 값 오류 | 시크릿 이름 오타 / 소스 저장소가 아닌 곳에 등록 |
| Pages 404 | Pages Source 가 `gh-pages` 로 설정됐는지, 배포가 한 번 이상 성공했는지 확인 |
| 화면 흰색/로드 실패 | `.nojekyll` 누락 → 워크플로 `enable_jekyll: false` 가 자동 생성(기본값) |
