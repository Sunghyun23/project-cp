# Godot 프로토타입

Godot 4.7.2 + GDScript + Compatibility 렌더러를 사용한다.
`project.godot`을 열거나 저장소 루트에서 `bash tools/dev.sh play`로 실행한다. API 서버를 먼저 실행해야 한다.

- scenes/main.tscn: 시작 씬.
- scripts/main.gd: 임시 캠핑 도형, 화면 흐름과 HTTP API 연결.
- assets/fonts/: Noto Sans KR과 OFL 라이선스.
- export_presets.cfg: 단일 스레드 Web 디버그 빌드.

임시 2D 화면과 제목이며 최종 표현 방식·화면 방향을 확정하지 않는다.
[개발 환경](../docs/07-technical/development.md), [프로토타입 명세](../docs/07-technical/prototype.md)를 참고한다.
