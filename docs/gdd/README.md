# 공유 게임 기획서

- [상세 게임 기획서 PDF](project-cp-game-design.pdf)
- [편집 원본 HTML](game-design.html)

두 개발자가 게임 규칙, 화면, 단계별 범위를 바꿀 때 관련 명세와 이 HTML을 함께 수정한다. 구현 상태나 후속 후보가 달라졌으면 해당 상태를 문서에 표시한다. 원본을 저장한 뒤 PDF를 다시 만들어 같은 변경에 포함한다.

## PDF 만들기

한글 출력에는 Noto Sans CJK KR을 권장한다. macOS에서는 Apple SD Gothic Neo도 사용할 수 있다.

```sh
python -m pip install playwright
python -m playwright install chromium
python tools/build-gdd.py
```

이미 설치한 Chromium을 사용하려면 `CHROMIUM_BIN`에 실행 파일 경로를 설정한다. GitHub의 PDF 화면에서는 다운로드 버튼으로 저장할 수 있다.
