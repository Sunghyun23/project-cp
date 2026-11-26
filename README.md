# project-cp

Android·웹용 캠핑 게임. 기획을 이어가며 Godot 로컬 프로토타입으로 흐름을 검증한다.

## 확정된 방향

- 플랫폼: Android + 웹. Godot 웹 빌드를 웹 서버에서 제공하고 공통 API를 사용한다.
- Android 화면: 일반 스마트폰·폴더블 커버·내부 화면의 다양한 해상도와 화면 비율 지원. [세부 사양](docs/07-technical/android.md)
- 프로토타입 환경: Godot 4.7.2, GDScript, Compatibility. 최종 표현 방식은 미정이다.
- 구현: AI가 코드 작성과 프로젝트 구성을 담당한다. API 서버는 Java + Spring Boot를 사용한다.
- 로그인: [Google 로그인 직접 연동 + Android·웹 게스트 플레이](docs/03-systems/authentication.md).
- 비용: 서버 호스팅을 제외한 운영비용 0원.
- 초기 호스팅: [시드니 AWS Lightsail 월 $7 한 대](docs/07-technical/aws-hosting.md)에 웹·API·PostgreSQL 배치. 최대 3명 테스트, 이후 서울 이전 준비.
- 초기 참여자: 두 명. 세부 역할 분담은 미정이다.
- 기획: 한 사람이 AI와 대화하며 게임을 구체화하고 AI가 문서 대부분을 작성·갱신한다.
- 개발 컴퓨터: 맥북 사용 계획. 이 초기 문서는 클라우드에서 작성했다.

## 시작하기

[기획 목차](docs/README.md) → [콘셉트](docs/01-vision/concept.md) → [MVP 범위](docs/01-vision/scope.md) 순서로 읽는다.
AI는 작업 전 [AGENTS.md](AGENTS.md)와 [대화 기반 기획 방식](docs/08-production/planning-workflow.md)을 읽는다.

## 구조

```text
AGENTS.md       AI 작업 규칙
docs/           기획·UX·아트·기술·제작 문서
design/         Figma 링크와 디자인 전달 규칙
art/source/     편집 가능한 에셋 원본
game/           Godot 프로토타입
server/         Java/Spring Boot API와 진행 저장
infra/          로컬 Caddy 설정
tools/          설치·실행·검증 스크립트
```

최종 2D/3D, 화면 방향, 핵심 재미와 전체 MVP는 아직 미정이다. 현재는 [한 주 흐름](docs/02-gameplay/session-flow.md)을 임시 2D 화면과 압축 조작으로 검증한다.
실행은 [개발 환경](docs/07-technical/development.md), 구현 범위와 임시 가정은 [프로토타입 명세](docs/07-technical/prototype.md)를 참고한다.
Figma는 UI·화면 흐름·아트 방향 설계에 활용할 수 있지만 모든 기능의 필수 선행 단계는 아니다.
작업과 버그는 GitHub Issues로 추적한다. 푸시는 항상 원격 `main` 브랜치에 하며, 다른 브랜치의 변경도 `main`에 반영한 뒤 푸시한다.

## 로컬 실행

Docker Desktop을 켜고 처음에는 `bash tools/setup-godot.sh`로 Godot과 Web 템플릿을 설치한다.

```sh
bash tools/dev.sh server
bash tools/dev.sh web
```

[로컬 프로토타입](http://localhost:8080)을 연다. macOS 창은 `bash tools/dev.sh play`로 실행한다.
