class_name CharacterDB
extends Resource
## 캐릭터 카탈로그 인덱스. 웹 빌드 호환을 위해 단일 리소스로 묶어 load 한다. 배열 순서 = 표시/기본 순서.

@export var characters: Array[CharacterData] = []
