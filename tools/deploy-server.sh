#!/usr/bin/env bash
# 로컬에서 빌드한 실행 산출물만 SSH로 배포한다. AWS 방화벽·리소스는 변경하지 않는다.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CP_SERVER_HOST:?CP_SERVER_HOST에 서버 주소를 지정해 주세요}"
ssh_key="${CP_SSH_KEY:-$HOME/.ssh/project-cp-sydney.pem}"
known_hosts="${CP_KNOWN_HOSTS:-$HOME/.ssh/project-cp-known-hosts}"
ssh_options=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts" -o ConnectTimeout=10)
test -f builds/web/index.html
mkdir -p builds/server
docker buildx build --platform linux/amd64 --load -t project-cp-api:0.1.0 server
docker save project-cp-api:0.1.0 | gzip > builds/server/api-image.tar.gz
tar -czf builds/server/site.tar.gz compose.server.yaml compose.public.yaml infra/Caddyfile infra/Caddyfile.public builds/web
(cd builds/server && shasum -a 256 api-image.tar.gz site.tar.gz > SHA256SUMS)
ssh "${ssh_options[@]}" "ubuntu@$CP_SERVER_HOST" 'sudo install -d -o ubuntu -g ubuntu -m 0750 /opt/project-cp'
scp "${ssh_options[@]}" builds/server/api-image.tar.gz builds/server/site.tar.gz builds/server/SHA256SUMS "ubuntu@$CP_SERVER_HOST:/opt/project-cp/"
ssh "${ssh_options[@]}" "ubuntu@$CP_SERVER_HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/project-cp
sha256sum -c SHA256SUMS
gzip -dc api-image.tar.gz | sudo docker load
tar -xzf site.tar.gz
python3 - <<'PY'
from pathlib import Path
import os, secrets
p=Path('.env')
if not p.exists():
    fd=os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write('POSTGRES_PASSWORD='+secrets.token_urlsafe(32)+'\n')
PY
compose_args=(-f compose.server.yaml)
if grep -q "^CP_WEB_HOST=" .env; then compose_args+=(-f compose.public.yaml); fi
sudo docker compose "${compose_args[@]}" config --quiet
sudo docker compose "${compose_args[@]}" up -d
# Recreate the bind mount so changed Caddy configuration is actually loaded.
sudo docker compose "${compose_args[@]}" up -d --no-deps --force-recreate web
python3 - <<'PY'
import urllib.request,json,time
for attempt in range(40):
    try:
        with urllib.request.urlopen('http://127.0.0.1:8080/api/v1/health/',timeout=2) as r:
            if json.load(r)['status']=='ok':
                print('API / PostgreSQL / Caddy health OK')
                break
    except Exception:
        time.sleep(1)
else:
    raise SystemExit('Health check failed; inspect compose logs')
PY
sudo docker compose "${compose_args[@]}" ps
REMOTE
