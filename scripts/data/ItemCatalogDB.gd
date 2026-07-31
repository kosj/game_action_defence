class_name ItemCatalogDB
extends Resource
## 무기/패시브/진화 카탈로그 인덱스. 웹 빌드 호환을 위해 단일 리소스로 묶어 load 한다.
## 배열 순서 = 표시/뽑기 순서.

@export var weapons: Array[WeaponData] = []
@export var passives: Array[PassiveData] = []
@export var evolutions: Array[EvolutionData] = []
