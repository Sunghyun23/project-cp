# GitHub 공유 배포

- 변경일: 2026-11-28
- 대상: 시드니 Lightsail 개발 서버, `main` 브랜치
- 방식: GitHub Actions의 수동 `Shared deployment` 작업
- 원본: [워크플로](../../.github/workflows/deploy.yml), [송신](../../tools/deploy-server.sh), [서버 적용](../../tools/deploy-release.sh)

## 다른 개발자가 배포하는 방법

1. [Actions → Shared deployment](https://github.com/Sunghyun23/project-cp/actions/workflows/deploy.yml)를 연다.
2. `Run workflow`를 누르고 브랜치를 `main`으로 선택한다.
3. `mode`를 고른다. `all`은 웹+API이며 기본값이다. `web`은 API 규칙 변경이 없는 클라이언트/로그인 수정에 사용한다. 확실하지 않으면 `all`을 선택한다.
4. 실행 결과가 초록색 `Success`인지 확인한다. Summary의 게임 링크·실제 커밋·빌드 해시를 확인하고 새로고침한다.

저장소 **Write 이상의 권한**이 필요하다. 아직 저장소 접근 권한이 없는 사람은 소유자가 Settings → Collaborators에서 초대한다. AWS 계정·개인 맥북·로컬 Godot·서버 개인 키는 배포 실행에 필요하지 않다. 개인에게 새 저장소 권한을 자동으로 부여하는 구성은 아니다.

`main` 푸시만으로 자동 배포하지 않는다. 수동 실행 당시의 main 커밋을 고정해 빌드한다. 다른 브랜치에서는 작업이 실행되지 않으며 `lightsail-sydney` 환경도 main만 허용한다. 배포 한 개만 진행하고 서버 적용 단계에도 파일 잠금을 사용한다.

## 자동으로 수행하는 일

1. Ubuntu 24.04 실행기에서 Godot 4.7.2·Web 템플릿을 설치한다.
2. 격리 DB의 API 검사, Web 내보내기·JavaScript 구문, 업무 입력, Mesa/Xvfb의 실제 낮/밤 배경 렌더링을 검사한다.
3. 전용 SSH 키와 미리 신뢰한 서버 호스트 키로 접속한다. 실행 중 새 서버 키를 무조건 신뢰하는 `ssh-keyscan` 우회는 사용하지 않는다.
4. 릴리스별 디렉터리로 산출물을 전송하고 SHA256과 아카이브 경로를 검사한다. 웹/API/DB 복구 사본을 서버 `backups/releases/<release>/`에 남긴다.
5. 웹 디렉터리를 교체하고 Caddy 바인드를 갱신한다. `all`은 API 이미지와 Compose/Caddy 구성도 함께 반영한다. `.env`·DB 볼륨·HTTPS 인증서는 덮어쓰지 않는다.
6. 공개 웹 빌드 해시·API/DB·게임 파일·인트로 동영상의 정상 응답을 확인한다. `/deployment.json`으로 실제 커밋과 실행 기록을 확인할 수 있다.

## 배포 키와 설정

저장소 Settings → Environments → `lightsail-sydney`에서 관리한다.

| 구분 | 이름 | 용도 |
|---|---|---|
| Secret | `CP_SSH_PRIVATE_KEY` | 개인 관리 키와 별도로 만든 서버 배포 전용 키 |
| Secret | `CP_SSH_KNOWN_HOSTS` | 기존에 검증한 서버 호스트 키 |
| Variable | `CP_SERVER_HOST` | 서버 접속 주소 |
| Variable | `CP_SERVER_USER` | 현재 `ubuntu` |
| Variable | `CP_PUBLIC_URL` | 공개 HTTPS 주소 |

전용 공개 키는 서버 `ubuntu`의 authorized_keys에 `restrict` 옵션으로 등록한다. 이 옵션은 SSH 포워딩·PTY 등을 제한하며 **임의의 원격 명령을 차단하는 역할은 아니다**. 배포 작업은 기존 서버 관리 권한으로 Docker/백업을 실행하므로 저장소 쓰기 권한은 신뢰하는 공동 개발자에게 부여한다. 비밀 키는 채팅·저장소·빌드 아티팩트에 넣지 않는다. 실행기 임시 키 파일은 작업 종료 시 삭제한다.

## 실패와 복구

빌드/검사/아카이브 검증 실패는 적용 전에 중단한다. 서버 적용 후 버전/상태 검사가 실패하면 이전 웹·API 이미지·구성으로 자동 복구를 시도하고 작업은 실패로 남긴다. DB는 자동으로 되돌리지 않는다. 스키마 변경이 있는 릴리스는 이전 API와의 호환을 별도로 확인해야 한다. 상태 검사를 통과했어도 기능 문제를 발견하면 수정 또는 revert를 main에 반영한 뒤 다시 실행한다.

복구 사본에는 `site.tar.gz`, `database.sql`과 `project-cp-api:rollback-<release>` 이미지 태그가 있다. DB 복구는 사용자 진행을 덮어쓰므로 관리자가 별도로 판단한다. 백업 자동 삭제는 설정하지 않았다. 서버 용량과 오래된 백업/이미지는 관리자가 확인한다.

## 로컬에서 같은 절차 실행

```sh
bash tools/dev.sh web
CP_SERVER_HOST=3.107.24.136 CP_DEPLOY_MODE=all bash tools/deploy-server.sh
python3 tools/verify-deployment.py https://project-cp-3-107-24-136.sslip.io
```

로컬 기본 관리 키 경로는 기존대로 유지한다. 다른 키는 `CP_SSH_KEY`, 호스트 키 파일은 `CP_KNOWN_HOSTS`로 지정한다.

## 첫 실행 검증

2026-11-28 [GitHub 실행 46121540023](https://github.com/Sunghyun23/project-cp/actions/runs/46121540023)에서 main 커밋 `e7a673c`의 `all` 배포를 성공했다. GitHub 호스팅 Ubuntu에서 API 검사 28개, 업무 입력, Mesa의 숲/호수 낮밤 렌더링, 웹 내보내기, 전용 키 접속, 백업·배포·공개 버전/게임/동영상 확인을 모두 통과했다.

서버 `/deployment.json`의 커밋·실행 URL 일치를 확인했다. 복구 지점은 `backups/releases/20261128T073251Z-e7a673c4a5b7-3880/`이며 백업 파일은 600 권한이다. 서버 전송 임시 폴더와 설정에 사용한 로컬 개인 키 사본을 삭제했다. 실패 자동 복구의 실제 장애 주입 검증은 미실행이며 위 검증은 정상 배포 경로에 해당한다.

## 공식 참고

- [수동 워크플로와 실행 권한](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [배포 환경과 브랜치 정책](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- [동시 배포 제어](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments)
