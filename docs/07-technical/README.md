# 기술 설계

- 상태: 초안 — Godot, Android·웹 서비스 확정
- 담당: AI, 기획자 검토
- 관련 문서: [개발 환경](development.md), [서버 추천안](server-architecture.md), [게임 프로젝트](../../game/README.md)

## Android 화면 지원

[Android 화면·해상도 사양](android.md)에 따라 일반 스마트폰과 폴더블의 커버·내부 화면, 다양한 해상도·화면 비율과 실행 중 접기·펼치기에 대응한다. 구체적인 기종·해상도 범위와 최종 화면 방향은 미정이다.

## 구현 시작 시 작성할 문서

- architecture.md: 씬·스크립트 책임, 상태 관리, 공용 객체 사용 기준.
- data-model.md: 고유 ID, 데이터 관계, 저장 형식·버전, 복원.
- [android.md](android.md): 화면·해상도 요구 작성 완료. 최소 Android 버전·대상 기기·성능 목표·앱 생명주기 상세는 후속 작성.

## 미정

프로토타입은 Godot 4.7.2·GDScript·Compatibility를 사용한다. [범위와 임시 가정](prototype.md), [환경·버전·검증](development.md)을 참고한다.
최종 2D/3D·화면 방향·지원 사양과 Android 도구 전체 구성은 미정이다.

## 로그인과 비용 제약

[로그인 명세](../03-systems/authentication.md)에 따라 Google 로그인을 자체 서버에 직접 연동한다.
서버 호스팅 외 운영비용 0원 조건을 기술 선택에 반영한다. 웹도 서비스하며 Android와 공통 API를 사용한다. 저장 시점·동시 접속·충돌 처리는 별도로 결정한다.

## 운영 호스팅

[AWS Lightsail 월 $7 요금제](aws-hosting.md)를 기준으로 설계한다. 현재는 설계 단계이며 리소스를 생성하지 않았다.
