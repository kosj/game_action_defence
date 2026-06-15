# Action Defence (Godot 4.x · Mobile WebGL)

탑다운 액션 디펜스 (뱀파이어 서바이버 / 탕탕특공대 스타일) 뼈대 프로젝트.

## 실행 방법
1. Godot 4.x (4.1 이상 권장)로 이 폴더(`project.godot`)를 연다.
2. 첫 실행 시 에디터가 `.tscn`/스크립트의 `uid`를 자동으로 채운다(정상).
3. F5(실행)로 플레이. 데스크톱에선 마우스 드래그가 터치로 변환되어 조이스틱이 동작한다.

## 조작
- 화면을 누르고 드래그 → 가상 조이스틱으로 이동.
- 무기는 사거리 안의 가장 가까운 좀비에게 자동 발사.

## 씬 / 스크립트 구조
```
Main.tscn ─ Main.gd
 ├─ Background (ColorRect)
 ├─ Player.tscn ─ Player.gd        # CharacterBody2D, 이동 + 자동공격
 │   ├─ Body (Polygon2D)
 │   ├─ CollisionShape2D (Circle)
 │   ├─ Camera2D                    # 플레이어 추적
 │   └─ Muzzle (Marker2D)           # 총알 발사 위치
 ├─ ZombieSpawner (Node) ─ ZombieSpawner.gd
 └─ HUD.tscn ─ HUD.gd (CanvasLayer)
     ├─ GoldLabel (Label)
     └─ Joystick (Control) ─ MobileJoystick.gd

Zombie.tscn ─ Zombie.gd   # CharacterBody2D, 추적 + 사망 시 골드 드랍
Bullet.tscn ─ Bullet.gd   # Area2D, 직선 이동 + 명중 데미지
Gold.tscn   ─ Gold.gd     # Area2D, 자석 수집

Autoload(싱글톤):
  Events ─ Events.gd       # 골드 카운트 + 시그널 버스
  Pool   ─ Pool.gd         # 제너릭 오브젝트 풀 (좀비/총알/골드 재사용)
```

## 오브젝트 풀링
좀비·총알·골드는 `queue_free()` 대신 `Pool.release()` 로 트리에서 떼어내 재사용한다
(GC 스파이크 방지 → WebGL 프레임 안정). 풀 대상 스크립트는 `on_spawn()` 으로 상태를
초기화하고, `_ready()` 는 시그널 연결 등 1회성 셋업만 담당한다. Main 에서 `Pool.prewarm()`
으로 첫 웨이브 전에 미리 채워둔다.

## 물리 레이어
1=player, 2=zombies, 3=bullets, 4=gold (project.godot 에 정의)

## 튜닝 포인트 (인스펙터 @export)
- Player: `move_speed`, `attack_range`, `attack_cooldown`
- Zombie: `speed`, `max_health`
- ZombieSpawner: `spawn_interval`, `max_zombies`, `spawn_margin`
- Gold: `magnet_radius`, `collect_radius`, `move_speed`
- MobileJoystick: `base_radius`, `knob_radius`, `dead_zone`, `activation_ratio`

## 아트 에셋
`assets/sprites/` 의 스프라이트는 [Kenney](https://www.kenney.nl/) 의 CC0(퍼블릭
도메인) 에셋입니다. 출처 팩:
- `player.png` — Top-down Shooter (`survivor1_gun`)
- `zombie.png` — Top-down Shooter (`zoimbie1_hold`)
- `bullet.png` — Top-down Tanks Redux (`bulletSand1_outline`)
- `gold.png`   — Platformer/Physics (`coinGold`)

PNG 는 Godot 에디터를 한 번 열면 `.import` 가 자동 생성됩니다(스크립트 uid 와 동일).

## WebGL 빌드
Project > Export > Web. 자세한 팁은 대화 내 설명 참고.
