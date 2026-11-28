# 캠핑 UI 디자인 시스템

- 상태: 재사용 컴포넌트 초안. 첫 캐릭터 선택 흐름에 적용. 기존 플레이 HUD 전체 교체는 후속.
- 기준: Godot 4.7.2 · Compatibility · 도스필기 16px/32px.

## 실행

프로젝트 루트에서:

```sh
.tools/godot/Godot.app/Contents/MacOS/Godot --path game res://ui/showcase.tscn
```

## 원본과 사용법

`theme/camping.tres`가 편집 가능한 공통 Theme다. `theme/build_theme.gd`는 재생성 스크립트이므로 스타일 변경은 여기에 반영한 뒤 아래 명령으로 갱신한다. `.tres`만 수정하고 재생성하면 변경이 덮어써진다. 가독성 시안의 공통 글꼴은 `assets/fonts/NotoSansKR.ttf`를 참조하며 글꼴 바이너리를 Theme에 중복 저장하지 않는다.

```sh
.tools/godot/Godot.app/Contents/MacOS/Godot --headless --path game --script res://ui/theme/build_theme.gd
```

| 씬 | 설정·사용 |
|---|---|
| components/action_button.tscn | text·disabled, 주요 행동은 theme_type_variation = PrimaryButton |
| components/paper_panel.tscn | 안쪽에 Container와 화면 내용을 추가 |
| components/hud_chip.tscn | Value.text로 날짜·금액 등 정보 설정 |
| components/choice_card.tscn | text·button_pressed·button_group으로 선택 상태 표시 |
| components/stamina_meter.tscn | Value.text와 Bar.value를 실제 게임 데이터에서 함께 갱신 |
| components/grid_cell.tscn | state: 0 빈 칸 / 1 적재 / 2 불가. 판정 로직은 호출자가 담당 |
| components/notice.tscn | message와 severity: 0 안내 / 1 주의 / 2 손실·오류 |

각 컴포넌트는 독립적으로 Theme를 참조한다. 상위 화면에서 Theme를 바꿀 경우 자식 컴포넌트에 명시된 Theme 참조도 함께 고려한다. 상태 색·테두리는 Theme의 타입 변형으로 관리한다. 숫자·문구·체력 데이터는 컴포넌트 자체에서 저장하거나 소비하지 않는다.

`showcase.tscn`은 이 원본들을 인스턴스화한 전시 화면이다. 760 미만 한 열·이상 두 열과 세로 스크롤은 전시용 배치이며 실제 게임 UI 레이아웃을 확정하지 않는다. 선택 카드의 표시 문구 전환은 전시 스크립트가 담당한다. 의상·캐릭터는 이 선택 카드 구조를 재사용할 수 있지만 전용 화면과 실제 이미지 연결은 후속이다.

## 검증 범위

macOS에서 PC 1280×1000, 폰 크기 390×844, 펼친 폴드 크기 820×920의 전시 상단/하단을 렌더링해 확인했다. 선택 상태는 전시 캡처에서 프로그래밍으로 전환했으며 실제 장치 입력 검증을 뜻하지 않는다. 외부 글꼴 참조로 정리한 최종 Theme는 PC에서 다시 확인했다. Android 실기기·웹·전체 키보드/패드·터치 입력은 미검증이다. 실제 게임 화면은 변경하지 않았다.

## 게임 화면과 스킨

`screens/character_select.tscn`은 첫 신규 진행의 SC-CHARACTER-SELECT다. 공통 선택 카드·버튼·알림을 캠핑장 풍경 위에 배치한다. `components/character_catalog.gd`는 남성·여성의 대기·걷기 SpriteFrames를 생성하며 미리보기와 플레이가 같은 시트를 사용한다.

나무/천 스킨 원본은 `assets/ui/*.svg`, 생성 소스는 `tools/build-ui-skins.py`다. SVG 생성 → Godot 가져오기 → Theme 재생성 순서로 갱신한다. Theme의 StyleBoxTexture는 사방 12px 9-slice를 사용한다. 스킨은 UI 재료이며 화면 전체 캡처와 구분한다.

최신 스킨은 장식 많은 목재 초안에서 얇은 경계·차분한 천/숲색으로 정돈한 시안이다. `tools/verify-character-select.gd`는 로컬 API를 사용한 별도 세션의 입력 이벤트·통신 실패 복구·저장·재접속 검사다. 물리 장치 검사와 구분한다.

`screens/first_week.tscn`은 첫 주 평일 수입 UI다. `ui_input.gd`는 두 진입 화면의 공통 패드 UI 매핑을 등록한다. `tools/verify-character-select.gd`는 이제 월~금 수입/체력과 쇼핑 진입도 검증한다. 실제 게임 전체 UI 교체와 구분한다.

`mvp_flow.tscn`은 장소·장비·예보/의상·적재·캠핑/조리·귀가/정산 모드를 연결한다. `grid_board.gd`는 2D 트렁크, `camp_editor_3d.gd`는 투명한 3D 격자/좌표와 **2D 장비 스프라이트**를 사용한다. 후자는 3D 캠핑장/입체 모델을 만드는 씬이 아니다. 상세 범위는 [MVP 구현 기준](../../docs/07-technical/mvp-v1.md)을 따른다.

폰·펼친 폴드 HUD 가독성 기준은 `ui_metrics.gd`가 관리한다. 웹 CSS 표시 크기/Android 밀도로 논리 크기를 계산하고 폭 960 이하에서 글자 최소 24·버튼 높이 최소 56을 적용한다. `tools/verify-ui-metrics.gd`로 PC 크기 복원·폰/폴드 전환·3배 밀도를 검사한다.
