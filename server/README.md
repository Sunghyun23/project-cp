# Java API 서버

Java 21·Spring Boot 4.2.0·Maven 3.9.11·PostgreSQL 17.7을 사용한다. 빌드·실행 Java 이미지는 [Dockerfile](Dockerfile)의 digest로 고정한다. Godot은 화면·입력을 담당하며, 현재 API는 기존 프로토타입의 진행·행동·저장 계약을 유지한다. 최종 게임 로직 분담은 미정이며 별도 웹 로그인과 Google 연결을 구현했다. Android 네이티브 인증은 미구현이다.

## 로컬 실행·검증

저장소 루트에서 Docker Desktop을 실행한 뒤 다음 명령을 사용한다.

```sh
bash tools/dev.sh server
bash tools/dev.sh web
bash tools/test-server.sh
```

웹은 `http://localhost:8080`, API는 `http://localhost:8000`이다. 테스트는 별도 Compose 프로젝트·임시 DB를 사용하며 실제 진행 볼륨을 지우지 않는다. 실제 PostgreSQL을 사용하는 통합 테스트와 JWT 검증 테스트 총 13개로 주간 진행·별점·입력 오류·동시 저장·기존 데이터 호환을 확인한다.

## API 계약

| 메서드·경로 | 동작 |
|---|---|
| `GET /api/v1/health/` | DB 연결까지 확인, 정상 200·불가 503 |
| `POST /api/v1/prototype/sessions/` | 임시 토큰·초기 진행·버전 발급, 201 |
| `GET /api/v1/prototype/state/` | Bearer 토큰의 진행 조회 |
| `POST /api/v1/prototype/actions/` | `command`, `choice`, `version`으로 행동·저장 |

진행 응답은 `state`, `version`을 포함한다. 토큰은 DB에 SHA-256 해시로 보관하며 클라이언트가 원본을 보관한다. 저장 시 행 잠금과 버전 검사로 충돌을 409로 반환한다. 잘못된 입력은 400, 없는 토큰은 401이다. 임시 테스트 세션은 확정된 게스트 ID·비밀번호·Google 인증을 대체하지 않는다.

Flyway 이력은 `cp_migrations`에 두며 기존 Django 테이블 `public.prototype_prototypesession`과 JSON 형식을 유지한다. 기존 DB에 새 빈 볼륨을 덮어씌우거나 데이터를 삭제하지 않는다. 로컬 전환 전 백업과 기존 토큰 조회 비교를 완료했다.

## 시드니 배포

사용자가 생성한 Lightsail Ubuntu 서버에 Docker를 설치한 구성을 전제로 한다. 로컬에서 Web을 빌드한 뒤 배포한다. SSH 키·서버 `.env`·빌드·백업은 커밋하지 않는다.

```sh
CP_SERVER_HOST=서버주소 bash tools/deploy-server.sh
```

스크립트는 amd64 Java 이미지를 로컬에서 만들고 웹 파일과 함께 업로드·체크섬 검증·배포한다. `/opt/project-cp/.env`는 없을 때만 난수 DB 비밀번호로 생성한다. PostgreSQL 영구 볼륨은 유지한다. 기본 `compose.server.yaml`은 루프백 8000·8080만 열며 공개 웹은 활성화하지 않는다. API·DB·웹 메모리 제한은 각각 384·160·64MiB, JVM 최대 힙은 160MiB다.

공개 웹은 `CP_WEB_HOST` 설정 후 `compose.public.yaml`을 함께 사용한다. Caddy 인증서 볼륨을 유지하고 80은 HTTPS로 전환하며 443으로 웹·API를 제공한다. AWS 방화벽의 80·443 허용은 별도다. API 8000과 DB 5432를 공개하지 않는다. 웹 로그인은 ID·비밀번호·복구 코드와 Google Identity Services를 사용한다. 새 웹 진행은 계정에 연결하고 HttpOnly·7일 만료 쿠키로 접근한다. 이전 익명 토큰 API는 호환용이며 자동 병합하지 않는다.

```sh
cd /opt/project-cp
sudo docker compose -f compose.server.yaml -f compose.public.yaml up -d
```

임시 DNS를 사용하면 해당 DNS 서비스와 현재 공인 IP에 의존한다. 고정 IP·소유 도메인·정식 인증·자동 백업은 후속 구성이다. 재배포 스크립트는 공개 override가 있으면 같은 구성을 유지한다.

## 확인한 결과와 한계

2026-11-26 시드니 실제 서버에서 3개 세션의 동시 저장, API 재시작 후 진행 유지, `pg_dump -Fc` 백업을 별도 임시 DB에 복원해 행 수 일치를 확인했다. 유휴 시 API 약 163MiB·DB 49MiB·Caddy 17MiB였고 호스트 가용 메모리는 약 315MiB였다. 짧은 테스트 결과이며 장시간·대량 부하의 보장은 아니다.

맥북 → SSH 터널 → 시드니 Caddy·Java·PostgreSQL 경로에서 연결 유지 후 측정했다. 조회는 각 20회, 동시 저장은 3명이 각 5회 수행했다.

| 요청 | 중앙값 | p95 |
|---|---:|---:|
| DB 포함 상태 확인 | 268ms | 549ms |
| 진행 조회 | 267ms | 528ms |
| 3명 동시 진행 저장 | 532ms | 536ms |

총 15회 저장과 재조회가 성공했다. 공개 HTTPS에서도 같은 방식으로 조회 각 20회·3명 저장 총 15회를 측정했다. 진행 조회 중앙값 287ms·p95 340ms, 동시 저장 중앙값 271ms·p95 280ms였다. 첫 상태 확인은 TCP·TLS 연결을 포함해 865ms였다. 휴대폰 회선은 별도 실측이 필요하다. 브라우저에서 시드니 Web 화면 표시를 확인했으며 Android 빌드·실기기 검증은 아직 수행하지 않았다. 초기 백업은 서버와 맥북의 Git 제외 경로에 각각 보관했다. 자동 정기 백업·서버 장애 복구 절차는 후속 작업이다.

## 웹 로그인 설정

`GOOGLE_CLIENT_ID`, `CP_WEB_ORIGIN`, `CP_SECURE_COOKIES`를 서버 `.env`에 설정한다. 공개 HTTPS는 해당 origin과 `true`, localhost는 `http://localhost:8080`과 `false`를 사용한다. 클라이언트 시크릿은 사용하지 않는다. Google Cloud 웹 OAuth 클라이언트의 승인된 JavaScript 원본도 일치해야 한다.

Web 내보내기 후 `tools/prepare-web.py`가 게임 진입점을 `/play.html`로 복사하고 `/`에 별도 로그인 HTML·CSS·JavaScript를 배치한다. 로그인 화면은 공식 Google 버튼을 사용한다. 게스트 가입 때 보여주는 복구 코드를 보관하고, 계정 화면에서 Google를 연결할 수 있다. 게임 내 계정 버튼으로 돌아간다.

`/api/v1/auth/` 아래 `config/`, `me/`는 GET, `register/`, `login/`, `recover/`, `logout/`, `google/`, `google/link/`는 POST다. 변경 요청에 허용 Origin과 `X-CP-Request: 1`을 요구한다. Google nonce는 5분 쿠키로 전달하고 ID 토큰 검증과 비교한다. 토큰·비밀번호·복구 원문은 로그에 남기지 않는다. 로그인 변경 요청은 IP별 분당 30회 제한한다.

V2 마이그레이션은 계정·로그인 세션 테이블을 추가하며 기존 진행을 삭제하지 않는다. 계정 복구는 이전 복구 코드와 모든 게임 세션을 폐기한다. 세부 정책·미구현 범위는 [계정 명세](../docs/03-systems/authentication.md)를 따른다. 공개 웹 Google 로그인 성공은 사용자가 확인했으며 Android 실기기 인증은 미검증이다.
