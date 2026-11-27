"""크기 조절 가능한 Godot 픽셀 UI 스킨. 벡터 원본은 저장소에서 직접 편집한다."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'game/assets/ui'
ROOT.mkdir(parents=True, exist_ok=True)


def skin(name, face, edge, light, panel=False):
    # 얇은 테두리·세 단계 모서리·작은 그림자만 사용한다.
    # 모서리를 12px 범위에 보관하므로 중앙이 늘어나도 픽셀 굵기는 유지된다.
    outline = 'M10 4H118V6H122V10H124V86H122V90H118V92H10V90H6V86H4V10H6V6H10Z'
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="96" viewBox="0 0 128 96" shape-rendering="crispEdges">
<path d="{outline}" transform="translate(0 2)" fill="#253b2d" opacity=".20"/>
<path d="{outline}" fill="{edge}"/>
<path d="M11 6H117V8H120V11H122V85H120V88H117V90H11V88H8V85H6V11H8V8H11Z" fill="{face}"/>
<path d="M13 8H115M10 12V20" stroke="{light}" stroke-width="2" fill="none"/>
<path d="M14 88H114" stroke="{edge}" stroke-width="1" opacity=".26"/>
'''
    if panel:
        # 천의 접힌 귀퉁이를 암시하는 아주 작은 점만 남긴다.
        svg += '<path d="M12 12H16V14H12ZM112 12H116V14H112Z" fill="#cdb88e"/>\n'
    svg += '</svg>\n'
    (ROOT / f'{name}.svg').write_text(svg)

skin('camp-panel', '#fff6df', '#ac9673', '#fffced', panel=True)
skin('wood-button', '#f3e7cd', '#b39b75', '#fff8e6')
skin('wood-hover', '#fff2d5', '#9c815b', '#fffbe9')
skin('wood-pressed', '#e5d4b3', '#947c5d', '#f3e4c6')
skin('wood-disabled', '#ddd8c8', '#b8af9b', '#e8e3d5')
skin('leaf-button', '#45634b', '#304d39', '#769373')
skin('leaf-hover', '#57785a', '#36573f', '#8da783')
skin('leaf-pressed', '#36513c', '#263e2d', '#607e60')
skin('choice-selected', '#e3ebd4', '#6d865d', '#f3f7e8')
