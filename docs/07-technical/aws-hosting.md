# AWS 운영 환경 설계

- 상태: 시드니 인스턴스·Docker 구성, Java 앱 배포·저장·백업 복원 검증 완료, 공개 HTTPS 접속 검증 완료
- 담당: 사용자(계정·리소스 생성), AI(승인된 직접 SSH 구성·검증)
- 관련 문서: [서버 아키텍처](server-architecture.md), [결정 기록](../decisions.md)
- 변경일: 2026-11-26

## 확정

초기 개발·테스트는 시드니 `ap-southeast-2`의 AWS Lightsail Linux 한 대에서 시작한다. 공인 IPv4 포함 월 $7·메모리 1GB·SSD 40GB 요금제를 기준으로 웹 파일·API·PostgreSQL을 함께 배치한다. 최대 동시 접속 3명은 테스트 조건이며 성능 보장 수치가 아니다.
별도 EC2 DB 계획(D021)은 초기 단계에서 D036으로 대체한다. PostgreSQL 사용료와 별도 DB 인스턴스 요금은 없지만 같은 서버의 메모리·CPU·디스크를 공유한다.
사용자가 `project-cp-dev-sydney`를 시드니 Zone A(`ap-southeast-2a`)에 생성했다. Ubuntu 24.04.5 LTS·x86_64이며 브라우저 SSH 확인 후 AI의 직접 SSH 관리를 허용했다. SSH 키는 맥북 사용자 SSH 폴더에 보관하며 저장소에 넣지 않는다. 고정 IP는 아직 할당하지 않았다.
Docker 29.10.1, Compose 5.8.0, containerd 2.4.2, Buildx 0.39.1을 공식 저장소의 명시 버전으로 설치하고 hello-world 실행을 확인했다.

## 계정과 무료 크레딧

2026-11-26 콘솔에서 Google/Builder ID 기반 프로젝트와 무료 플랜의 $100 크레딧·남은 기간 182일을 확인했다. 단순 Builder ID 프로필 생성과 AWS 프로젝트·콘솔 접근을 구분한다.
현재 계정은 시드니에 리전 제한이 있다. 당장은 고급 AWS 기능을 활성화하지 않는다. 이후 서울 이전에는 계정의 다중 리전 사용 조건을 다시 확인한다.
AWS Free Tier 크레딧으로 Lightsail 사용을 시작할 수 있다. 서버 기본요금만 월 $7이면 6개월 합계는 $42다. 크레딧은 다른 서비스와 공유되며 무료 플랜의 기간·잔액 제한을 별도로 따른다. 추가 비용과 세금 등의 적용을 포함한 무료 운영 기간을 보장하지 않는다. 예전 Lightsail 단기 무료 체험과 현재 크레딧 제도를 혼동하지 않는다.

## 배치와 운영 제안

- Caddy + Java API + PostgreSQL을 Docker Compose로 관리하는 방향을 제안한다. Java + Spring Boot는 D038로 확정했다. 기존 Django 프로토타입 API를 Java로 전환한다. 버전·내장 Tomcat·영구 볼륨은 고정해 배포했다. 현재 서버 구성은 `compose.server.yaml`을 사용하며 Caddy 8080·API 8000을 서버 루프백에만 바인딩한다. 공개 테스트 웹은 별도 `compose.public.yaml`과 HTTPS를 사용한다. 정식 계정은 미구현이며 테스트 진행만 저장한다. 임시 `sslip.io` DNS 이름으로 인증서를 발급해 공개 HTTPS를 제공한다. 고정 IP·소유 도메인은 아직 없으며 IP 변경 시 이름도 바뀐다.
- 웹 파일과 `/api/v1/`를 같은 HTTPS 주소로 제공하고 Android도 같은 API를 사용한다. 웹·Android 게임 실행은 사용자 기기가 담당한다.
- 외부 공개 포트는 웹 80·443, SSH는 관리 주소로 제한한다. DB 5432는 인터넷에 공개하지 않고 내부 연결만 허용한다.
- 고정 IP·호스트 이름·HTTPS 구성을 정한다. 도메인 등 유료 자원은 별도로 선택한다. Android에 서버 IP를 하드코딩하지 않도록 한다.
- Godot 빌드·이미지 빌드·테스트는 맥북이나 CI에서 수행하고 서버에는 산출물을 배포한다.
- API 워커 1개부터 시작하고 DB 연결 수를 제한한다. 인증·저장·백업 피크를 포함한 전체 메모리·지연을 측정한다. 비밀번호 해시 보안을 낮춰 메모리를 절감하지 않는다.
- 로그 회전·이미지 정리·보안 업데이트를 구성한다. 성능이 부족하면 증설·DB 분리를 재검토한다. 초기 Redis·작업 큐·로드밸런서·NAT Gateway는 도입하지 않는다.

실제 3개 세션 저장·재시작 복구·백업 복원을 확인했다. 메모리와 맥북에서 시드니까지의 응답 시간은 [서버 검증 기록](../../server/README.md#확인한-결과와-한계)에 기록했다.

## 백업·비용과 한계

앱과 DB가 같은 서버이므로 장애 시 함께 중단되며 자동 장애 전환은 없다. DB 데이터는 영구 저장 공간에 두고 정기 논리 백업과 실제 복원을 검증한다. 초기 논리 백업은 실제 복원을 확인한 뒤 서버와 맥북의 Git 제외 경로에 보관했다. 정기 백업의 대상·암호화·주기·보존 기간은 미정이다. OS·DB 업데이트와 복구는 직접 관리한다.
기본 월 $7 외에 스냅샷·초과 전송·추가 저장 공간·도메인 등 비용이 생길 수 있다. 잔여 크레딧과 청구를 확인하며 1GB 성능이나 총비용 상한을 약속하지 않는다.

## 서울 이전 준비

서버 설정·버전·배포 절차를 파일로 관리한다. 서울에 새 서버를 구성하거나 인스턴스 스냅샷을 리전 간 복사할 수 있다. 최종 전환 때 쓰기를 중단하고 PostgreSQL을 백업·복원한 뒤 접속 주소를 전환한다. 계정·진행·웹·Android API를 확인하고 이전 서버를 정리한다. 데이터 유실·분기를 막기 위해 두 DB에 동시에 쓰지 않는다.
초기에는 점검 시간을 허용하는 이전을 가정하며 무중단 이전은 별도 요구다. 이전 기간의 중복 서버·스냅샷·전송 비용을 고려한다. 서울 이전 시점과 상세 절차는 미정이다.

## 참고

- [Lightsail 요금](https://aws.amazon.com/lightsail/pricing/)
- [Lightsail 무료 크레딧 안내](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-frequently-asked-questions-faq-billing-and-account-management.html)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [리전 간 Lightsail 스냅샷 복사](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-copying-snapshots-from-one-region-to-another.html)
