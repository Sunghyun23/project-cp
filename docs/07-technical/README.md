# 기술 설계

- 상태: 초안 — Godot, Android·웹 서비스 확정
- 담당: AI, 기획자 검토
- 관련 문서: [개발 환경](development.md), [서버 추천안](server-architecture.md), [게임 프로젝트](../../game/README.md)

## 구현 시작 시 작성할 문서

- architecture.md: 씬·스크립트 책임, 상태 관리, 공용 객체 사용 기준.
- data-model.md: 고유 ID, 데이터 관계, 저장 형식·버전, 복원.
- android.md: 최소 Android 버전, 대상 기기, 해상도, 성능 목표, 앱 생명주기.

## 미정

정확한 엔진 버전, 스크립트 언어, 렌더러, 화면 방향, 지원 사양.
Godot 4 안정 버전과 GDScript는 이전 대화의 추천안이다.
환경 구성 시 버전을 고정하고 빌드·검증 명령을 실제 확인하여 기록한다.

## 로그인과 비용 제약

[로그인 명세](../03-systems/authentication.md)에 따라 Google 로그인을 자체 서버에 직접 연동한다.
서버 호스팅 외 운영비용 0원 조건을 기술 선택에 반영한다. 웹도 서비스하며 Android와 공통 API를 사용한다. 저장 시점·동시 접속·충돌 처리는 별도로 결정한다.
