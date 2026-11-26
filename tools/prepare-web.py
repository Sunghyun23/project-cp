"""리모트 미리보기에서 실패한 HTTP 상태를 숨기지 않도록 빌드에 진단 추가."""
from pathlib import Path
import gzip

script = Path("builds/web/index.js")
source = script.read_text()
original = "new Error(`Failed loading file '${file}'`)"
replacement = "new Error(`게임 파일 로딩 실패: ${file} (HTTP ${response.status} ${response.statusText}). 요청 주소: ${response.url}`)"
if original not in source:
    raise SystemExit("Godot 로더 형식이 바뀌었습니다. 오류 진단 패치를 확인해 주세요.")
script.write_text(source.replace(original, replacement))

for path in Path("builds/web").iterdir():
    if path.suffix in (".pck", ".wasm", ".js"):
        path.with_suffix(path.suffix + ".gz").write_bytes(gzip.compress(path.read_bytes(), mtime=0))
