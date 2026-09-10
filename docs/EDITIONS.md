# 배포 버전

하나의 프로젝트에서 Godot export feature tag로 버전을 선택합니다.

| Export preset | 용도 | 화면 | 저장 공간 |
|---|---|---|---|
| Web | itch.io 무료 웹 체험판 (`demo`) | 1280×720, 16:9 | Zombie Buster Demo |
| Windows Full | 유료 Windows 다운로드 (`full`) | 1280×720, 크기 변경 가능 | Zombie Buster |
| Mobile Preview | 향후 모바일 UI 확인용 웹 빌드 (`mobile_preview`) | 360×640, 9:16 | Zombie Buster Mobile Preview |

가로판은 UI 논리 크기 2272×1278을 사용합니다. 기존 세로 UI 높이를 유지하면서 가로 공간을 확장하므로 텍스트·카드 크기를 일괄 축소하지 않습니다. 다른 화면비에서는 Godot `canvas_items / keep`으로 잘림을 막습니다. 모바일 프리뷰는 기존 720×1280 논리 크기를 유지합니다.

랭킹 메뉴는 모든 버전에서 제거했습니다. 내부 최고 기록 저장은 기존 기록·신기록 판정에 계속 사용합니다. 출시 프리셋에는 `cheats` 태그가 없습니다. 웹/Windows는 광고 부활이 숨겨지며 키보드로 이동합니다. 터치 기기와 모바일 프리뷰에서는 조이스틱을 사용할 수 있습니다.

체험판 콘텐츠 제한은 아직 미정입니다. 현재 Web은 **콘텐츠 제한 없이 WEB DEMO 표시만** 적용됩니다. 판매 전 제한할 아레나·시간·캐릭터 범위를 확정해야 합니다. Mobile Preview는 Android/iOS 출시 패키지가 아니며, 네이티브 프리셋·서명·스토어 연동은 모바일 출시 때 추가합니다.

## 빌드

Godot 4.3 및 같은 버전의 export templates가 필요합니다. 출력 디렉터리를 만든 뒤 실행합니다.

```text
godot --headless --export-release "Web" build/web/index.html
godot --headless --export-release "Windows Full" build/windows/ZombieBuster.exe
godot --headless --export-release "Mobile Preview" build/mobile-preview/index.html
```

에디터 실행에는 export custom feature가 적용되지 않습니다. 기본 실행은 Windows와 같은 가로 정식판 구성이며, 모바일/체험판 동작은 해당 프리셋의 export로 확인합니다.

## itch.io 업로드

1. Web 출력 폴더 내용을 ZIP으로 묶고 ZIP 루트에 `index.html`이 오도록 합니다.
2. itch.io 프로젝트를 HTML 게임으로 설정하고 웹 ZIP을 브라우저 실행 파일로 선택합니다. 임베드 크기는 1280×720 또는 동일한 16:9 비율을 사용합니다.
3. Windows 출력 폴더를 별도 ZIP으로 올리고 Windows 플랫폼을 지정합니다.
4. Windows 파일에 개별 최소 가격을 설정합니다. 웹 게임은 무료 플레이를 유지합니다. 가격은 사용자가 결정합니다.
5. 비공개/초안 페이지에서 브라우저 실행·전체 화면·새로고침 후 저장 복원·실제 다운로드 구성을 확인하고 공개합니다.

공식 문서: [HTML5 업로드](https://itch.io/docs/creators/html5), [가격 설정](https://itch.io/docs/creators/pricing), [Godot feature tags](https://docs.godotengine.org/en/4.3/tutorials/export/feature_tags.html).
