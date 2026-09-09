# 엔지니어 8방향 IK 걷기

헌터에서 검증한 고정 파츠 + 2관절 IK 방식을 엔지니어에 적용했다.

- 8방향 × 24프레임, 0.96초 반복.
- 발 접지 60%, 양발 위상차 50%.
- 상체와 네일건은 프레임마다 같은 파츠를 재사용한다.
- 허벅지는 넓은 멜빵바지 허리에 맞춰 충분한 부피로 제작했다.
- `torso_parts.png`, `leg_parts.png`, `foot_parts.png`가 imagegen 원본 파츠다.
- `engineer_walk_24x8.png`는 256px 검토 시트다.
- `overview.gif`, `east.gif`, `bones.gif`, `walk_*.gif`는 반복 확인용이다.
- `export_game.mjs`가 `assets/characters/engineer/`에 128px 게임 시트를 출력한다.

`verify.mjs`는 2,000개 시점에서 반복 경계의 위치·속도 연속, 고정 뼈 길이,
항상 한 발 이상 접지, 발 높이 0 이상을 검사한다. `smoke.mjs`는 미리보기의
재생·정지·속도·방향·관절 표시를 확인한다.

내장 image_gen으로 파츠 3장을 생성했으며 최종 프레임 자체는 생성 모델로
그리지 않았다. 사용 프롬프트는 `prompts.md`에 보존한다.
