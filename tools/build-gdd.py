"""Render the shared game design document to its checked-in PDF."""
import base64
import os
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
DOCUMENT = ROOT / "docs" / "gdd"
HERO_PATH = "../../game/assets/pixel/campsite-night.png"

html = (DOCUMENT / "game-design.html").read_text(encoding="utf-8")
hero = base64.b64encode((DOCUMENT / HERO_PATH).read_bytes()).decode("ascii")
html = html.replace(f'src="{HERO_PATH}"', f'src="data:image/png;base64,{hero}"')

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        executable_path=os.environ.get("CHROMIUM_BIN"),
    )
    page = browser.new_page()
    page.set_content(html, wait_until="load")
    page.evaluate("document.fonts.ready")
    page.pdf(
        path=DOCUMENT / "project-cp-game-design.pdf",
        print_background=True,
        prefer_css_page_size=True,
    )
    browser.close()
