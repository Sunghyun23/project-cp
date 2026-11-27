# 공통 디자인 시스템 렌더링 검토

- 일자: 2026-11-27
- 대상: `game/ui/showcase.tscn`, 작업 트리의 커밋 전 변경
- 연계: D125~D127, SC 화면별 검증 전의 공통 UI
- 환경: macOS · Godot 4.7.2 · OpenGL Compatibility · Apple M4 Pro

## 결과

PC 1280×1000, 폰 크기 390×844, 펼친 폴드 크기 820×920에서 전시 씬 상단과 하단을 렌더링했다. 한 열/두 열 대응과 세로 스크롤 하단 캡처, 선택됨/미선택, 적재/불가, 손실 알림을 확인했다. HUD가 최소 너비 없이 글자를 세로로 줄바꿈하던 문제를 최소 너비로 수정했다. 카드의 긴 선택 안내는 짧게 줄였다.

글꼴을 Theme에 내장하는 대신 외부 참조하도록 정리한 최종 상태는 PC에서 재확인했다. 폰·폴드 캡처는 같은 글꼴 렌더링 옵션을 사용한 참조 정리 직전 상태다. 렌더링 로그에 스크립트 오류는 없고 구문 검사를 통과했다. Headless 에디터 가져오기는 글꼴 리소스를 생성했지만 macOS 시스템 인증서 조회·샌드박스 밖 에디터 설정 저장 오류를 출력했다. 일반 실행의 렌더링·캡처는 정상 종료했다.

| 환경 | 상단 | 하단·선택 상태 |
|---|---|---|
| PC | [캡처](../../../design/mvp/previews/ui-system/components-desktop.png) | [캡처](../../../design/mvp/previews/ui-system/components-desktop-bottom.png) |
| 폰 크기 | [캡처](../../../design/mvp/previews/ui-system/components-phone.png) | [캡처](../../../design/mvp/previews/ui-system/components-phone-bottom.png) |
| 폴드 크기 | [캡처](../../../design/mvp/previews/ui-system/components-fold.png) | [캡처](../../../design/mvp/previews/ui-system/components-fold-bottom.png) |

## 남은 확인

장치 크기 비교는 실제 Android 실행이 아니다. 선택 전환과 스크롤은 캡처 코드로 수행했으며 사용자 클릭·터치·Tab·패드 입력을 실증하지 않았다. 웹·Android·기기 접기/펼치기·안전 영역·전체 글자 범위·실제 게임 화면 적용은 미검증이다.
