# 픽셀 그래픽과 3D 조명·이펙트

- 상태: 사용자 방향 확정·MVP 1차 구현, 공개 MVP 반영·사용자 시각 검토 대기
- 변경일: 2026-11-28
- 담당: AI 구현·검증, 사용자 시각 검토

## 방향

사용자가 Final Fantasy Resonance처럼 픽셀 그래픽에 분명한 3D 이펙트와 조명을 결합하도록 요청했다. 기존 배경의 물결·풀 흔들림·시차·화면 입자·고정 위치 불티/비를 제거한다. 2D 배경·방향별 장비·캐릭터 스프라이트는 유지하고, 게임 화면을 별도 입체 캠핑장 모델로 교체하지 않는다.

스타일 참고는 [공식 소개](https://blog.playstation.com/2026/09/03/final-fantasy-resonance-ps5-demo-available-today-sephiroth-revealed)의 픽셀 아트와 HD-2D 조합이다. 타 작품의 에셋을 사용하거나 동일한 완성도·렌더링 파이프라인을 구현했다고 주장하지 않는다.

## 현재 구현

- 기존 `campsite.gdshader`는 정적인 배경 크롭만 처리한다. 로그인 배경의 확대 애니메이션도 제거했다. 낮밤의 정적인 원화 차이와 캐릭터 프레임 애니메이션은 유지한다.
- 장비와 캐릭터는 같은 World3D의 조명을 받는 2D Sprite3D/AnimatedSprite3D다. 실제 OmniLight3D가 배치된 랜턴·버너 위치를 따르고, 이동·철거 시 조명과 발광 표시도 갱신한다.
- DirectionalLight3D로 낮의 따뜻한 빛·밤의 푸른 빛을 만든다. 배경 이미지 자체의 모든 나무/지형이 실제 3D 모델인 것은 아니다.
- 픽셀 스프라이트가 실제 그림자 맵을 만들고, 투명한 지면 shadow catcher가 배경 위에 그림자를 합성한다.
- 부드러운 광원 번짐·바닥 빛·빛기둥·불티·부유 입자·비는 3D 공간의 제한된 메시 풀로 구현한다. 빛기둥은 반투명 메시 표현이며 물리적인 볼류메트릭 포그가 아니다.
- 투명 Viewport는 premultiplied alpha로 합성하고, 발광 재질은 경계 마스크를 RGB에도 적용해 사각형이 드러나지 않게 한다. 픽셀 본체는 최근접 필터로 유지하고 빛 주변만 부드럽게 표현한다.
- 2026-11-28 사용자 피드백: 캐릭터·장비가 작고 뭉개져 보이면 이펙트보다 도트 식별성을 우선한다. 절반 해상도 Viewport를 원래 화면 해상도로 바꾸고 캐릭터에도 최근접 필터를 명시했다. 전체 화면 bloom은 끄고 국소 발광과 실제 조명·그림자는 유지하되 과노출을 줄였다.
- 현장 전체를 화면 안에 유지하면서 카메라의 세로 점유 비율을 최소 44%, 가로를 최소 96%로 조정했다. 캐릭터 프레임 높이는 1.7→2.6 월드 단위로 키웠다. 이 값은 프로토타입 표시 조정이며 배치 범위·아이템 충돌/받침·서버 좌표는 바꾸지 않는다. 최종 픽셀 밀도·아트 승인은 별도다.
- `효과` 버튼으로 끄면 추가 조명·그림자·입자·발광을 숨기고 정적인 배경과 원래 스프라이트로 돌아간다. 입력·날씨·체력 등 게임 규칙은 바꾸지 않는다. 숨긴 화면/비활성 창에서는 이펙트 시간을 진행시키지 않는다.
- 예전 `camp_lighting_3d.gd`의 별도 디오라마 비교 코드는 주 화면과 메뉴에서 연결을 제거했다.

## 데이터·구현 위치

### 2026-11-28 밤 배경 색상 보정 수정

사용자가 밤 전환 시 배경이 바뀌지 않는다고 보고했다. 소나무 숲은 같은 원화에 밤 색을 적용하지만 `campsite.gdshader`가 텍스처만 출력해 CanvasItem의 `modulate`를 무시했다. vertex 단계의 색을 varying으로 전달하고 크롭된 텍스처에 곱해 실제 밤 색을 적용한다. fragment의 기본 COLOR는 이미 기본 UV 텍스처를 포함하므로 중복 곱하지 않는다. [공식 COLOR 설명](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html#color-and-texture)

`tools/verify-night-background.gd`는 네트워크 없는 실제 Main 화면을 macOS Compatibility GPU로 렌더링해 배경 픽셀을 비교한다. 숲·호수의 17:59→18:00, 낮 복원, 수동 낮밤 전환, 저장 응답 후 수동 설정 유지를 검사했다. 숲은 새 야간 원화를 생성한 것이 아니라 기존 밤 색상 보정이 동작하도록 수정한 것이다. 게임 시간·장비·배치 규칙은 바꾸지 않는다.

밤 배경 수정 웹 빌드 `b15090130d2232e934f8e6eb4cb670a6e3cf379f2c157d2226c054becb12841f`를 공개 반영했다. 웹 복구 지점 `20261128T064624Z`를 보존했으며 API·DB는 변경하지 않았다. Android 실기기 GPU 검증은 별도다.

`game/effects/camp_effects_3d.gd`가 광원·입자의 수명과 원본 위치를 관리한다. `radiance.gdshader`·`shadow_catcher.gdshader`는 합성 재질이다. 현장 좌표·회전·소유 데이터는 기존 배치 구조를 사용하며 추가 서버 규칙이나 모닥불 아이템을 생성하지 않는다. 버너 주변 효과는 현재 프로토타입의 시각 연출로, 새로운 연료 소모 규칙을 뜻하지 않는다.

## 호환·검증

Godot 4.7.2 Compatibility를 유지한다. [공식 렌더러 표](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)에 따라 실제 광원·그림자를 사용하고 미지원 볼류메트릭 포그/CompositorEffects는 사용하지 않는다. 전체 화면 glow는 선명도 보정을 위해 껐다. [투명 Viewport 합성](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html)도 확인했다.

- 실제 macOS Compatibility GPU 렌더링으로 야간/낮·폰/폴드 크기·효과 끄기·그림자 끄기를 확인했다.
- 동일한 고정 시간으로 그림자 ON/OFF를 렌더링해 서로 다른 출력이 있음을 확인했다.
- `tools/verify-camp-effects.gd`: 광원 위치 추적·조명받는 캐릭터·철거·효과 끄기 초기 상태·일시정지·정적 배경 검사 통과.
- 배치/회전 입력 회귀 검사 통과. 전체 게임 흐름의 결과는 [MVP 검증](../05-ux/reviews/2026-11-27-mvp.md)에 기록한다.
- 실제 Android 기기·웹 브라우저별 GPU 성능/발열 검증은 아직 미실행이다. 창 크기 확인을 실기기 검증으로 취급하지 않는다.

[야간](../../design/mvp/previews/mvp/effects-night.png) · [폰](../../design/mvp/previews/mvp/effects-phone.png) · [효과 끄기](../../design/mvp/previews/mvp/effects-off.png)

## 공개 반영

1차 이펙트는 웹 빌드 `b9cc2d40de1356891a6663aa0d161bb04e92bfab37c517207b2349be63310460`으로 배포했다. 이후 선명도·표시 크기·낮밤/감상·적재 조작을 보완한 현재 빌드는 `9b56fe79c6d5e45ff62a964509cfa5c623d1813e8ad3b5833c3310be02ed3dd2`이다. build-info 일치·게임 파일 HTTP 200·API/DB 정상 상태를 확인했다. 현재 웹/API/DB 복구 지점은 `20261127T154557Z`이며 DB 스키마는 변경하지 않았다. 공개 API 임시 세션으로 조기 출발·낮밤 배경/조명 전환·이동·현장 드래그·식사·귀가 손실·다음 주·재접속 검사도 통과했다. 브라우저/Android GPU별 실제 플레이 성능 검증과 최종 아트 승인은 남아 있다.

[선명도 보정 폰](../../design/mvp/previews/mvp/crisp-phone.png) · [폴드](../../design/mvp/previews/mvp/crisp-fold.png) · [PC](../../design/mvp/previews/mvp/crisp-pc.png)
