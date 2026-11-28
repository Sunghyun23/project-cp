#!/usr/bin/env bash
# deploy-server.sh가 SSH 표준입력으로 전송하는 서버 적용 단계.
set -euo pipefail
release="${1:?release required}"
mode="${2:?mode required}"
[[ "$release" =~ ^[0-9]{8}T[0-9]{6}Z-[a-f0-9]{12}-[0-9]+$ ]] || exit 2
[[ "$mode" == all || "$mode" == web ]] || exit 2
cd /opt/project-cp
test -f .env
stage="$PWD/incoming/$release"
backup="$PWD/backups/releases/$release"
exec 9> .deploy.lock
flock -n 9 || { echo '다른 배포가 진행 중입니다.' >&2; exit 1; }
(cd "$stage" && sha256sum -c SHA256SUMS)
# 경로 이탈·심볼릭 링크 없이 허용된 배포 파일만 받는다.
python3 - "$stage" "$mode" <<'PY'
import json,sys,tarfile
from pathlib import Path,PurePosixPath
stage=Path(sys.argv[1]);mode=sys.argv[2]
allowed={'compose.server.yaml','compose.public.yaml','infra/Caddyfile','infra/Caddyfile.public'} if mode=='all' else set()
with tarfile.open(stage/'site.tar.gz') as archive:
    for member in archive.getmembers():
        path=PurePosixPath(member.name)
        if path.is_absolute() or '..' in path.parts or not (member.isfile() or member.isdir()):
            raise SystemExit('허용하지 않는 배포 아카이브 항목')
        if str(path) not in allowed and not (str(path)=='builds/web' or str(path).startswith('builds/web/')):
            raise SystemExit('허용하지 않는 배포 파일: '+str(path))
    archive.extractall(stage/'unpack',filter='data')
source=stage/'unpack/builds/web/build-info.json'
json.loads(source.read_text())
(stage/'expected-build-info.json').write_bytes(source.read_bytes())
PY
compose_args=(-f compose.server.yaml)
if grep -q '^CP_WEB_HOST=' .env; then compose_args+=(-f compose.public.yaml); fi
sudo docker compose "${compose_args[@]}" config --quiet
umask 077
mkdir -p "$backup"
tar -czf "$backup/site.tar.gz" builds/web compose.server.yaml compose.public.yaml infra/Caddyfile infra/Caddyfile.public
sudo docker compose "${compose_args[@]}" exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' < /dev/null > "$backup/database.sql"
rollback_tag="project-cp-api:rollback-$release"
if [[ "$mode" == all ]]; then sudo docker image tag project-cp-api:0.1.0 "$rollback_tag"; fi
printf 'Backup: %s\n' "$backup"
apply_started=false
rollback() {
  local failure="$1"
  trap - ERR
  set +e
  if [[ "$apply_started" == true ]]; then
    echo '배포 실패. 이전 웹/API로 복구합니다. DB는 자동으로 되돌리지 않습니다.' >&2
    mkdir -p "$stage/restore"
    tar -xzf "$backup/site.tar.gz" -C "$stage/restore"
    if [[ -d builds/web ]]; then mv builds/web "$stage/failed-web"; fi
    mv "$stage/restore/builds/web" builds/web
    for file in compose.server.yaml compose.public.yaml infra/Caddyfile infra/Caddyfile.public; do cp "$stage/restore/$file" "$file"; done
    if [[ "$mode" == all ]]; then sudo docker image tag "$rollback_tag" project-cp-api:0.1.0; fi
    sudo docker compose "${compose_args[@]}" up -d
    sudo docker compose "${compose_args[@]}" up -d --no-deps --force-recreate web
  fi
  printf '복구 사본: %s\n' "$backup" >&2
  exit "$failure"
}
trap 'rollback "$?"' ERR
apply_started=true
if [[ "$mode" == all ]]; then
  gzip -dc "$stage/api-image.tar.gz" | sudo docker load
  for file in compose.server.yaml compose.public.yaml infra/Caddyfile infra/Caddyfile.public; do cp "$stage/unpack/$file" "$file"; done
fi
# 기존 Caddy 바인드는 이전 디렉터리를 계속 보며 재생성 시 새 파일로 전환한다.
mv builds/web "$stage/previous-web"
mv "$stage/unpack/builds/web" builds/web
if [[ "$mode" == all ]]; then sudo docker compose "${compose_args[@]}" up -d; fi
sudo docker compose "${compose_args[@]}" up -d --no-deps --force-recreate web
python3 - "$stage/expected-build-info.json" <<'PY'
import json,sys,time,urllib.request
from pathlib import Path
expected=json.loads(Path(sys.argv[1]).read_text())
for attempt in range(45):
    try:
        with urllib.request.urlopen('http://127.0.0.1:8080/api/v1/health/',timeout=2) as response: health=json.load(response)
        with urllib.request.urlopen('http://127.0.0.1:8080/build-info.json',timeout=2) as response: actual=json.load(response)
        if health.get('status')=='ok' and health.get('database')=='ok' and actual==expected:
            print('PASS deployed web version / API / PostgreSQL');break
    except Exception:
        pass
    time.sleep(1)
else:
    raise SystemExit('배포 후 버전/상태 확인 실패')
PY
trap - ERR
sudo docker compose "${compose_args[@]}" ps
rm -rf "$stage"
printf '배포 완료. 복구 사본: %s\n' "$backup"
