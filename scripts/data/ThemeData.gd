class_name ThemeData
extends Resource
## 아레나 테마 데이터(Phase 6). 비주얼셋(바닥/배경 색 + 장식 스타일) + 해금 게이팅.
## 오브젝트/기믹/테마보스는 후속(6-B/6-C)에서 gimmick_key/boss 로 확장.

@export var id: String = ""
@export var display: String = ""
@export var desc: String = ""

# 비주얼셋 — Ground.gd 가 읽어 바닥/배경을 그린다.
@export var bg: Color = Color(0.10, 0.16, 0.08)
@export var tile_a: Color = Color(0.13, 0.20, 0.10)
@export var tile_b: Color = Color(0.16, 0.24, 0.13)
@export var mark: Color = Color(0.22, 0.31, 0.16)
@export var detail_style: String = "grass"   # 장식 그리기 분기: grass/desert/stone/frozen

## 해금 게이팅(캐릭터와 동일 규칙). 둘 다 비면 기본 해금.
@export var unlock_cost: int = 0
@export var unlock_achievement: String = ""

## 기믹 키(단일, 레거시) / 테마 보스 아키타입.
@export var gimmick_key: String = ""
@export var boss_key: String = ""

## 테마별 방해 기믹 목록 — 여러 종을 가중 없이 균등 랜덤으로 스폰한다. 비어 있으면 gimmick_key 로 폴백.
@export var gimmick_keys: PackedStringArray = PackedStringArray()

## 미장센(장식 프롭) 키 목록 — PropField 가 필드에 흩뿌린다. 비어 있으면 프롭 없음.
##   suburb=fence/wreck_car, city=wreck_car/tank, lab=(아트 준비 후 채움)
@export var prop_keys: PackedStringArray = PackedStringArray()

## 이 아레나에서 나올 수 있는 날씨 — WeatherSystem 이 슬롯마다 여기서 하나를 뽑는다(+ 맑음).
##   rain / snow / dust. 비어 있으면 항상 맑음.
@export var weather_keys: PackedStringArray = PackedStringArray()
