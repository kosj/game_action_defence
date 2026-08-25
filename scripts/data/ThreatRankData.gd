class_name ThreatRankData
extends Resource
## 위협 등급 한 칸(HANDOFF P1-12 / CONTENT_PLAN §2 Phase A).
##
## 값은 **누적 결과**다. 등급 5 를 고르면 2~5 의 규칙이 전부 반영된 수치가 여기 들어 있다 —
## 런타임이 등급을 거슬러 올라가며 합산하지 않게 하려는 것이다(생성기가 미리 접는다).
##
## 모든 배수는 **기존 밸런스 테이블 위에 곱한다.** 등급 1 은 전부 항등원(1.0 / 0)이라
## 지금까지의 측정치가 그대로 기준선으로 남는다 — 수용 기준 ①이 이것이다.

@export var rank: int = 1

## 곱하는 손잡이(1.0 = 변화 없음)
@export var enemy_hp_mult: float = 1.0
@export var enemy_speed_mult: float = 1.0
@export var boss_hp_mult: float = 1.0
@export var chest_interval_mult: float = 1.0    # >1 이면 보물상자가 귀해진다
@export var elite_interval_mult: float = 1.0    # <1 이면 엘리트 팩이 잦아진다

## 더하는 손잡이(0 = 변화 없음)
@export var boss_heal_charges_add: int = 0
@export var start_health_add: int = 0

## 이 등급에서 **새로 붙는** 규칙 한 줄(UI 표시용). 누적 목록이 아니라 "이번에 늘어난 것".
##   rule_key    Locale 키("%s" 하나를 받는다)
##   rule_amount 이미 서식이 끝난 수치("+10%" / "-1"). 언어와 무관하므로 로케일에 넣지 않는다.
@export var rule_key: String = ""
@export var rule_amount: String = ""
