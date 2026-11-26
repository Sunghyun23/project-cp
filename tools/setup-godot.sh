#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$(uname -s)" != Darwin ]; then
  echo '이 설치 스크립트는 macOS용입니다.' >&2
  exit 1
fi
mkdir -p .tools/downloads .tools/godot
curl -fL --retry 2 'https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=macos.universal.zip' -o .tools/downloads/godot.zip
unzip -q -o .tools/downloads/godot.zip -d .tools/godot
curl -fL --retry 2 'https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=export_templates.tpz' -o .tools/downloads/templates.tpz
template_dir="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
mkdir -p "$template_dir"
unzip -j -o .tools/downloads/templates.tpz 'templates/web*' 'templates/version.txt' -d "$template_dir"
.tools/godot/Godot.app/Contents/MacOS/Godot --version
