# project-cp

Android용 캠핑 게임. 현재는 기획 단계이며 Godot으로 구현한다.

## 확정된 방향

- 플랫폼: Android + 웹. Godot 웹 빌드를 웹 서버에서 제공하고 공통 API를 사용한다.
- 엔진: Godot. 정확한 버전과 언어는 개발 환경 구성 시 결정한다.
- 구현: AI가 코드 작성과 프로젝트 구성을 담당한다.
- 로그인: [Google 로그인 직접 연동 + Android·웹 게스트 플레이](docs/03-systems/authentication.md).
- 비용: 서버 호스팅을 제외한 운영비용 0원.
- 운영 호스팅: [AWS Lightsail 월 $7 요금제 기준](docs/07-technical/aws-hosting.md).
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
game/           향후 Godot 프로젝트
```

2D/3D, 화면 방향, 핵심 재미, MVP 기능은 아직 미정이다. 텐트 설치·모닥불·요리 등은 예시이며 확정 기능이 아니다.
Godot 프로젝트는 아직 생성하지 않았다. 실행·빌드 명령은 구성 후 검증하여 기록한다.
Figma는 UI·화면 흐름·아트 방향 설계에 활용할 수 있지만 모든 기능의 필수 선행 단계는 아니다.
작업과 버그는 GitHub Issues로 추적하고 이후 변경은 작업 브랜치와 PR을 활용한다.
