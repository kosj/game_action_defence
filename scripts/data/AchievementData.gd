class_name AchievementData
extends Resource
## 도전과제 데이터. metric(추적 지표)이 threshold 에 도달하면 해금되고 reward_gold(메타 골드)를 준다.
## metric 키: total_kills / boss_kills(누적) · best_time(초, 단일 런 최고 생존) · best_level(단일 런 최고 레벨).

@export var id: String = ""
@export var display: String = ""
@export var desc: String = ""
@export var metric: String = ""
@export var threshold: int = 1
@export var reward_gold: int = 0
