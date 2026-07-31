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

## 동작 모듈. ""=기존 코드가 처리(gun/orb/lightning/garlic/holy).
## "projectile"=ProjectileWeapon 모듈이 아래 파라미터로 자동 조준 발사.
@export var module: String = ""
@export_group("Projectile Module")
@export var fire_interval: float = 0.5    # 발사 간격(초)
@export var pellets: int = 1              # 1회 발사 탄 수
@export var spread: float = 0.0           # 부채꼴 분산(라디안)
@export var pierce: int = 0               # 관통 수(0=첫 명중 소멸)
@export var knockback: float = 0.0        # 넉백 세기(0=탄 기본값)
@export var proj_speed: float = 700.0     # 탄속
@export var proj_damage: int = 1          # 기본 데미지
@export var dmg_per_level: int = 1        # 레벨당 데미지 증가
@export var proj_scale: float = 1.0       # 탄 크기 배수
@export_group("Area Module")
@export var area_radius: float = 80.0     # 콘 길이(화염방사기) / 장판·폭발 반경
@export var area_duration: float = 0.0    # 장판 지속(초) / 지뢰 최대 수명
