class_name CharacterData
extends Resource
## 플레이어 캐릭터 데이터. 시작 무기 + 시그니처 패시브 + 시작 스탯 보정으로 차별화한다(스펙).
## 조건부 고유 트레잇(저체력 공격력↑ 등)은 후속(Phase 4-B)에서 trait 키로 확장.

@export var id: String = ""
@export var display: String = ""
@export var desc: String = ""
@export var color: Color = Color.WHITE

## 런 시작 시 기본 자동총(gun)에 더해 추가로 보유하는 무기(빈 문자열/"gun"이면 추가 없음).
@export var start_weapon: String = ""
## 런 시작 시 Lv1로 보유하는 시그니처 패시브(빈 문자열이면 없음).
@export var signature_passive: String = ""

## 캐릭터 전용 스프라이트 경로(빈 문자열이면 씬 기본 player.png 사용). 사이드뷰·오른쪽 향함.
@export var sprite_path: String = ""
@export var sprite_scale: float = 1.0   # body 스케일(스프라이트 크기 정규화용)
## 러닝 시트(run_<id>.png)의 가로 프레임 수. 원본 아트의 고유 포즈 수에 맞춰 시트를
## 만들고 여기 기록한다 — 7포즈를 8칸에 욱여넣으면 중복 프레임에서 스터터가 생긴다.
@export var run_frames: int = 8

## 시작 스탯 보정 — recompute 말미에 upgrade_* 에 더해진다(패시브/무기 위에 얹힘).
@export var bonus_max_health: int = 0
@export var bonus_bullet_damage: int = 0
@export var bonus_move_speed: int = 0
@export var bonus_atk_speed: int = 0
@export var bonus_area: int = 0
@export var bonus_crit: int = 0
@export var bonus_greed: int = 0    # 인게임 골드/경험치 획득 보정(엔지니어 재화↑ 등)

## 조건부 고유 트레잇 키(Phase 4-B): "veteran"/"hunter"/"engineer" 등.
@export var trait_key: String = ""

## 캐릭터 전용 궁극기 아이템(id) — 런 시작 시 Lv1 보유. 주기적으로 자동 발동해 일정 시간
## 화면 전체의 적에게 지속 피해를 준다(레벨업 카드로 강화). 카탈로그의 evolved=true 무기라
## 다른 캐릭터의 뽑기/상자에는 등장하지 않는다.
@export var ultimate_weapon: String = ""

## 해금 게이팅(Phase 5-C). 둘 다 비어있으면(cost 0 & achievement "") 기본 해금.
@export var unlock_cost: int = 0            # 메타 골드로 구매 해금(0=구매 게이트 없음)
@export var unlock_achievement: String = "" # 이 도전과제 달성 시 자동 해금(""=없음)
