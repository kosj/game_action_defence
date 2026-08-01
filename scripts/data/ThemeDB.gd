class_name ArenaThemeDB
extends Resource
## (ThemeDB 는 Godot 엔진 싱글톤 이름과 충돌하므로 ArenaThemeDB 사용)
## 테마 카탈로그 인덱스. 웹 빌드 호환을 위해 단일 리소스로 묶어 load 한다. 배열 순서 = 표시/난이도 순서.

@export var themes: Array[ThemeData] = []
