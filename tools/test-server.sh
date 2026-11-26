#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
trap 'docker compose -f compose.test.yaml down' EXIT
docker compose -f compose.test.yaml run --rm tests
