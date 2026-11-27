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

# Replace engine branding in the export shell without changing its loader logic.
html_path = Path("builds/web/index.html")
html = html_path.read_text().replace('<html lang="en">', '<html lang="ko">')
html = html.replace('</head>', '<link rel="stylesheet" href="/loading.css">\n</head>')
start = html.index('\t\t\t<img id="status-splash"')
end = html.index('\n\t\t\t<div id="status-notice"', start)
html = html[:start] + '''
<div class="camp-loading">
 <div class="loading-heading"><span>작은 쉼표, 커다란 주말</span><h1>이번 주말은 캠핑</h1><span class="little-star">✦ · ✦</span></div>
 <div class="loading-card"><span class="tag">주말 여행 준비 중</span><h2>캠프를 준비하고 있어요</h2><p>텐트를 펼치고, 따뜻한 불을 지피는 중이에요.</p>
 <div class="loading-meter"><span id="loading-stage">캠핑 장비 챙기는 중</span><span id="camp-percentage">준비 중</span></div>
 <progress id="status-progress" aria-label="게임 다운로드 진행률"></progress>
 <p id="loading-tip">따뜻한 커피 한 잔처럼 느긋하게 기다려 주세요.</p><p class="loading-footer">첫 방문에는 조금 더 걸릴 수 있어요.</p></div>
</div>''' + html[end:]
html = html.replace('statusProgress.max = total;', '''statusProgress.max = total;
                    const ratio = current / total;
                    document.getElementById('camp-percentage').textContent = Math.floor(ratio * 100) + '%';
                    document.getElementById('loading-stage').textContent = ratio >= 1 ? '마지막으로 캠프 둘러보는 중' : '캠핑 장비 챙기는 중';
                    document.getElementById('loading-tip').textContent = ['호숫가에 텐트 칠 자리를 찾고 있어요.', '커피와 토스트도 잊지 않고 챙겼어요.', '따뜻한 불 앞에서 잠시 쉬어 가요.'][Math.min(2, Math.floor(ratio * 3))];''')
# Avoid displaying the default engine favicon when no game icon is configured.
import re
html = re.sub(r'<link[^>]+(?:index.icon.png|index.apple-touch-icon.png)[^>]*>', '', html)
html_path.write_text(html)

# 게임 내보내기 파일 이름은 유지하고 별도의 로그인 진입점을 제공한다.
import shutil
root = Path("builds/web")
shutil.copy2(root / "index.html", root / "play.html")
shutil.copy2("web/login.html", root / "index.html")
for name in ("login.css", "login.js", "loading.css"):
    shutil.copy2(Path("web") / name, root / name)
(root / "assets").mkdir(exist_ok=True)
for name in ("campsite-day.png", "campsite-night.png"):
    shutil.copy2(Path("game/assets/pixel") / name, root / "assets" / name)
shutil.copy2("game/assets/fonts/NotoSansKR.ttf", root / "assets/NotoSansKR.ttf")

# 웹 시작·로그인 화면도 같은 원본을 참조한다.
shutil.copy2("game/assets/fonts/DOSPilgi.ttf", root / "assets/DOSPilgi.ttf")
shutil.copy2("game/assets/pixel/camper-animations.png", root / "assets/camper-animations.png")
(root / "assets/ui").mkdir(exist_ok=True)
for source in Path("game/assets/ui").glob("*.svg"):
    shutil.copy2(source, root / "assets/ui" / source.name)

# 배포 확인용: 인증 정보 없이 소스와 빌드 시각만 제공한다.
import hashlib, json
from datetime import datetime, timezone
fingerprint = hashlib.sha256()
for folder in (Path("game"), Path("web")):
    for source in sorted(folder.rglob("*")):
        if not source.is_file() or ".godot" in source.parts:
            continue
        fingerprint.update(str(source).encode())
        fingerprint.update(source.read_bytes())
(root / "build-info.json").write_text(json.dumps({
    "protocol": "mvp-1-xyz-sprites",
    "source_sha256": fingerprint.hexdigest(),
    "built_at": datetime.now(timezone.utc).isoformat()
}, ensure_ascii=False))

(root / "assets/licenses").mkdir(exist_ok=True)
for source in Path("game/assets/fonts").glob("*.txt"):
    shutil.copy2(source, root / "assets/licenses" / source.name)
# 사전 압축 파일도 본체와 일치하도록 매 빌드마다 갱신한다.
import gzip
for name in ("index.pck", "index.wasm", "index.js"):
    source = root / name
    if source.exists():
        (root / (name + ".gz")).write_bytes(gzip.compress(source.read_bytes(), compresslevel=6, mtime=0))
