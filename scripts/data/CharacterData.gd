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

## 시작 스탯 보정 — recompute 말미에 upgrade_* 에 더해진다(패시브/무기 위에 얹힘).
@export var bonus_max_health: int = 0
@export var bonus_bullet_damage: int = 0
@export var bonus_move_speed: int = 0
@export var bonus_atk_speed: int = 0
@export var bonus_area: int = 0
@export var bonus_crit: int = 0
@export var bonus_greed: int = 0    # 인게임 골드/경험치 획득 보정(엔지니어 재화↑ 등)

## 조건부 고유 트레잇 키(Phase 4-B 예약): "veteran"/"hunter"/"engineer" 등.
@export var trait_key: String = ""
