# 베테랑 8방향 IK 걷기

헌터와 엔지니어에서 검증한 고정 파츠 + 2관절 IK 방식을 베테랑에 적용했다.

- 8방향 × 24프레임, 0.96초 반복.
- 발 접지 60%, 양발 위상차 50%.
- 상체와 기관총은 프레임마다 같은 파츠를 재사용한다.
- 넓은 전술 벨트와 근육질 체형에 맞춰 허벅지와 부츠 부피를 키웠다.
- `torso_parts.png`, `leg_parts.png`, `foot_parts.png`가 imagegen 원본 파츠다.
- `veteran_walk_24x8.png`는 256px 검토 시트다.
- `overview.gif`, `east.gif`, `bones.gif`, `walk_*.gif`는 반복 확인용이다.
- `export_game.mjs`가 `assets/characters/veteran/`에 128px 게임 시트를 출력한다.

`verify.mjs`는 반복 경계의 위치·속도 연속, 고정 뼈 길이, 접지 및 발 높이를
검사한다. 내장 image_gen으로 파츠 3장을 생성했으며 사용한 전체 프롬프트는
`prompts.md`에 보존한다.
