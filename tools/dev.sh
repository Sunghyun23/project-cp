#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot/Godot.app/Contents/MacOS/Godot}"
case "${1:-help}" in
  server)
    if [ ! -f .env ]; then cp .env.example .env; fi
    mkdir -p builds/web
    docker compose up -d --build
    ;;
  play|web|check)
    if [[ "$("$godot_bin" --version)" != 4.7.2.stable.* ]]; then
      echo 'Godot 4.7.2가 필요합니다. GODOT_BIN 경로를 확인해 주세요.' >&2
      exit 1
    fi
    case "$1" in
      play) exec "$godot_bin" --path game ;;
      web)
        mkdir -p builds/web
        cp server/src/main/resources/gameplay/*.json game/data/
        "$godot_bin" --headless --path game --editor --import --quit
        "$godot_bin" --headless --path game --check-only --script res://scripts/main.gd
        "$godot_bin" --headless --path game --export-debug Web ../builds/web/index.html
        python3 tools/prepare-web.py
        ;;
      check)
        "$godot_bin" --headless --path game --editor --import --quit
        bash tools/test-server.sh
        ;;
    esac
    ;;
  stop) docker compose down ;;
  *) echo '사용법: bash tools/dev.sh {server|play|web|check|stop}' ;;
esac
