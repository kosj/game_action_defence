class_name WeaponData
extends Resource
## 무기 카탈로그 데이터. 표시 정보 + 성장 상한. 수치는 이 .tres 에서 조정(하드코딩 금지).
## 동작(Bullet/Orb/Lightning 등)과 레벨→스탯 매핑은 ItemDB.recompute 가 처리한다.

@export var id: String = ""
@export var display: String = ""          # 카드/HUD 표시 이름
@export var desc: String = ""             # 카드 설명
@export var color: Color = Color.WHITE    # 카드 테마색
@export var max_level: int = 8            # 최대 강화 레벨
@export var evolved: bool = false         # 진화 무기(카드로 안 뜸, 진화로만 획득)
