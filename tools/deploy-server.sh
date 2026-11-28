#!/usr/bin/env bash
# 로컬/공유 CI에서 빌드하고 서버에는 실행 산출물만 보낸다.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CP_SERVER_HOST:?CP_SERVER_HOST에 서버 주소를 지정해 주세요}"
mode="${CP_DEPLOY_MODE:-all}"
case "$mode" in all|web) ;; *) echo '배포 범위는 all 또는 web입니다.' >&2; exit 2 ;; esac
ssh_key="${CP_SSH_KEY:-$HOME/.ssh/project-cp-sydney.pem}"
known_hosts="${CP_KNOWN_HOSTS:-$HOME/.ssh/project-cp-known-hosts}"
server_user="${CP_SERVER_USER:-ubuntu}"
ssh_options=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts" -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4)
test -f "$ssh_key" && test -f "$known_hosts"
test -f builds/web/build-info.json
test -f builds/web/index.html
revision="$(git rev-parse HEAD)"
release="$(date -u +%Y%m%dT%H%M%SZ)-${revision:0:12}-$$"
bundle="$PWD/builds/server/$release"
mkdir -p "$bundle"
# 공개 추적 정보만 넣고 인증 값은 포함하지 않는다.
CP_RELEASE="$release" CP_REVISION="$revision" python3 - <<'PY'
from pathlib import Path
import json,os
Path('builds/web/deployment.json').write_text(json.dumps({
    'release':os.environ['CP_RELEASE'],'revision':os.environ['CP_REVISION'],
    'run_url':('https://github.com/'+os.environ['GITHUB_REPOSITORY']+'/actions/runs/'+os.environ['GITHUB_RUN_ID']) if os.environ.get('GITHUB_RUN_ID') else ''
}))
PY
if [[ "$mode" == all ]]; then
  docker buildx build --platform linux/amd64 --load -t project-cp-api:0.1.0 server
  docker save project-cp-api:0.1.0 | gzip > "$bundle/api-image.tar.gz"
  COPYFILE_DISABLE=1 tar --no-xattrs -czf "$bundle/site.tar.gz" compose.server.yaml compose.public.yaml infra/Caddyfile infra/Caddyfile.public builds/web
  (cd "$bundle" && shasum -a 256 api-image.tar.gz site.tar.gz > SHA256SUMS)
else
  COPYFILE_DISABLE=1 tar --no-xattrs -czf "$bundle/site.tar.gz" builds/web
  (cd "$bundle" && shasum -a 256 site.tar.gz > SHA256SUMS)
fi
target="$server_user@$CP_SERVER_HOST"
ssh "${ssh_options[@]}" "$target" "umask 077; mkdir -p /opt/project-cp/incoming/$release"
scp "${ssh_options[@]}" "$bundle/"* "$target:/opt/project-cp/incoming/$release/"
ssh "${ssh_options[@]}" "$target" "bash -s -- $release $mode" < tools/deploy-release.sh
echo "Deployed revision: $revision ($mode)"
