#!/usr/bin/env bash
# GitHub의 Linux x86_64 실행 환경. 프로젝트 엔진 버전과 Web 템플릿을 함께 고정한다.
set -euo pipefail
cd "$(dirname "$0")/.."
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
version=4.7.2
mkdir -p .tools/downloads .tools/godot
curl -fL --retry 3 "https://downloads.godotengine.org/?version=$version&flavor=stable&slug=linux.x86_64.zip" -o .tools/downloads/godot-linux.zip
unzip -qo .tools/downloads/godot-linux.zip -d .tools/godot
mv ".tools/godot/Godot_v${version}-stable_linux.x86_64" .tools/godot/godot
chmod +x .tools/godot/godot
curl -fL --retry 3 "https://downloads.godotengine.org/?version=$version&flavor=stable&slug=export_templates.tpz" -o .tools/downloads/templates.tpz
template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable"
mkdir -p "$template_dir"
unzip -jo .tools/downloads/templates.tpz 'templates/web*' 'templates/version.txt' -d "$template_dir"
.tools/godot/godot --headless --version
