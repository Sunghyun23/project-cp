# 기획 문서 안내

한 사람이 AI와 대화하며 작성·갱신하는 게임 기획의 기준이다.

| 분류 | 역할 |
|---|---|
| [01-vision](01-vision/concept.md) | 콘셉트, 핵심 경험, MVP 범위 |
| [02-gameplay](02-gameplay/README.md) | 핵심 반복 구조, 세션, 조작, 성장 |
| [03-systems](03-systems/README.md) | 시스템별 규칙, 상태 변화, 예외 |
| [04-content](04-content/README.md) | 아이템, 요리, 장소 등 콘텐츠 |
| [05-ux](05-ux/README.md) | 화면 흐름, 피드백, 첫 플레이 안내 |
| [06-art-audio](06-art-audio/README.md) | 아트 방향, 에셋 규격, 사운드 |
| [07-technical](07-technical/README.md) | Godot 구조, 데이터, Android 환경 |
| [08-production](08-production/planning-workflow.md) | 기획 진행, 제작 단계, 완료 기준 |
| [templates](templates/system-spec.md) | 시스템 명세 작성 양식 |
| [결정 기록](decisions.md) | 주요 결정과 변경 이유 |

## 작성 순서

콘셉트 → MVP → 핵심 반복 구조 → 첫 플레이 흐름 → 시스템 → UX·에셋 → 완료 기준.
예정된 상세 문서는 분류별 README에 나열하고 필요한 시점에 작성한다.

## 관리 원칙

상태는 `초안 / 검토 중 / 확정 / 폐기`로 표시한다. 내용이 섞이면 항목별 확정·제안·미정을 구분한다.
문서마다 담당과 관련 문서를 명시한다. 날짜는 실제 변경일만 기록한다.
규칙의 기준은 시스템 문서에 두고 다른 문서는 링크로 참조한다.
수치가 많아지면 게임 데이터로 분리하고 문서에는 의미·단위·설계 의도를 남긴다.
