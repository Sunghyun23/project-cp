# 개발 환경과 실행

- 상태: 로컬 프로토타입 구성, Android 환경 미완료
- 담당: AI, 기획자 검토
- 관련 문서: [기술 설계](README.md), [프로토타입 명세](prototype.md)
- 변경일: 2026-11-26

## 고정 환경

| 항목 | 버전·설정 |
|---|---|
| 개발 머신 | macOS Apple Silicon |
| Godot | 4.7.2.stable.official.ed1daf0bf, 일반판 |
| 언어·렌더러 | GDScript, Compatibility |
| 임시 화면 | 초기 macOS 창 1100×760, 실제 창·브라우저 크기에 맞춤, 센서 방향. 최종 방향 미정 |
| Web | 단일 스레드, 디버그 내보내기 |
| Python | Docker 이미지 3.13.7-slim-bookworm |
| Django / DRF | 5.2.19 / 3.18.3 |
| Psycopg | 3.3.9, 간접 의존성도 requirements.txt에 고정 |
| PostgreSQL | Docker 이미지 17.7-bookworm |
| Caddy | Docker 이미지 2.10.2-alpine |
| Docker / Compose 검증 버전 | 28.3.2 / 2.38.2 |

Android 도구는 아직 설치하지 않았다. 다음 구성을 초기 기준으로 기록한다: OpenJDK 17, SDK Platform 35, Build-Tools 35.0.1, NDK 28.1.13356709, CMake 3.10.2.4988404. JDK 패치·Command-line Tools·Platform-Tools의 정확한 버전은 Android 구성 시 추가 고정한다. 현재 APK/AAB 빌드 환경은 미완성이다. 기존 JDK 24는 Android 기준으로 채택하지 않았다.

## 처음 설치

Docker Desktop을 실행한다. Godot은 `.tools/godot/`에 설치하고 같은 버전의 Web 템플릿은 macOS 사용자 Godot 표준 폴더에 설치한다. 설치 스크립트는 공식 배포본을 받는다.

```sh
bash tools/setup-godot.sh
bash tools/dev.sh server
bash tools/dev.sh web
```

`server`는 `.env`가 없을 때만 `.env.example`을 복사한다. 예시 값은 로컬 전용이다.

## 실행과 종료

- 브라우저: <http://localhost:8080>. 같은 출처의 `/api/`를 사용한다.
- macOS 창: `bash tools/dev.sh play`. API는 `127.0.0.1:8000`을 사용한다.
- 검사: `bash tools/dev.sh check`.
- Web 재빌드: `bash tools/dev.sh web` 후 브라우저 새로고침.
- 서버 코드 변경: `bash tools/dev.sh server`로 재빌드.
- 종료: `bash tools/dev.sh stop`. DB 볼륨은 유지된다.

다른 Godot 설치는 `GODOT_BIN=/절대/경로/Godot bash tools/dev.sh play`로 지정한다. 스크립트는 4.7.2 버전을 검사한다.
웹 8080·API 8000은 루프백에만 바인딩하고 DB 포트는 공개하지 않는다. Django 개발 서버를 사용하는 로컬 구성이다. 운영 프로세스·HTTPS·배포는 별도 작업이다.

## 저장과 복원

진행은 PostgreSQL의 `prototype-db` 볼륨에 저장한다. 클라이언트는 임시 세션 토큰을 `user://prototype_session.cfg`에 보관한다. 토큰이 같으면 재실행·새로고침 후 이어한다. Web 저장소와 macOS 앱 저장소는 분리되어 각각 별도 진행으로 시작한다.
브라우저 저장소나 DB 볼륨을 지우면 이전 진행에 접근할 수 없다. 정식 ID·비밀번호·Google 로그인·복구 코드는 미구현이다.

## 검증

2026-11-26에 Godot 가져오기·Web 내보내기, Django 설정·마이그레이션 검사, 실제 PostgreSQL을 사용하는 테스트 6개를 통과했다. 자동 테스트는 두 요리의 주간 완주·저장 재조회, 숙련도 보너스 별, 오래된 요청 거부, 잘못된 토큰·단계·선행 조건을 확인한다.
Codex 리모트 미리보기의 319×1163 화면에서도 검은 레터박스 없이 UI가 표시되는 것을 확인했다. 고정 비율 축소를 끄고 실제 뷰포트에 맞추며 좁은 화면에서 텍스트·버튼을 줄바꿈한다. 화면·입력 확인과 자동 테스트를 구분한다. Android 빌드·실기기, 15분 플레이 시간, 성능·재미, AWS 배포·백업 복원은 미검증이다.

## 공식 참고

- [Godot 다운로드](https://godotengine.org/download/macos/)
- [Godot Android 내보내기](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Django 배포 버전](https://www.djangoproject.com/download/)
- [Psycopg 설치](https://www.psycopg.org/install/)

## 모바일 컴퓨터 미리보기의 로딩 오류 조사

사용자 기기의 `컴퓨터 미리보기`에서 `Failed loading file 'index.pck'`가 발생했다. 맥북 Chrome 및 도구로 연 미리보기의 성공만으로 사용자 기기의 성공을 판단하지 않는다. pck 응답에 `application/octet-stream`을 명시하고 개발 파일에 `Cache-Control: no-store`를 적용했다. Web 내보내기 뒤 `tools/prepare-web.py`가 로더 실패 메시지에 HTTP 상태·요청 주소를 추가하고 사전 gzip 파일을 만든다. 로컬 요청의 압축 해제 결과가 원본 pck와 같은 SHA-256임을 확인했다. 사용자 기기의 후속 스크린샷에서 원격 미리보기 URL의 pck 요청이 HTTP 403 Blocked로 거부되는 것을 확인했다. 로컬 서버에서는 같은 파일이 정상 제공된다. 차단 규칙·권한을 바꾸는 지원 설정은 현재 도구와 확인한 문서에서 찾지 못했다. 실제 사용자 미리보기의 재생은 미완료이며 로컬 성공과 구분한다.
