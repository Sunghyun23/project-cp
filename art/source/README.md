# 에셋 원본

편집 가능한 이미지·오디오 등의 제작 원본 위치다.
게임용 출력물은 game/assets/에 두고 중복 관리를 피한다. 현재 AI 생성 PNG와 프롬프트는 game/assets/pixel/에 함께 보관하며 편집 레이어 원본이 있다고 가정하지 않는다.
에셋 목록에 출처·사용 조건을 기록한다. 큰 바이너리가 생기면 Git LFS를 검토한다.
제작 도구·형식·용량 기준은 미정이다.

제작 대상과 현재 자원의 대응은 [기획 기반 에셋 목록](../../docs/06-art-audio/asset-list.md)을 기준으로 관리한다.

아이템·장소·캐릭터 제작은 [어셋 제작 규칙](../../docs/06-art-audio/asset-spec.md)을 따른다. 작성용 초안은 [아이템](templates/item.asset.example.json)·[장소](templates/campsite.asset.example.json)·[캐릭터](templates/character.asset.example.json) 예시를 복사해 시작한다. 신규 원본·메타데이터의 기본 위치는 `items/<id>/`, `places/<id>/`, `characters/<id>/`이며 기존 PNG·프롬프트는 이동하지 않는다. 예시의 수치는 임시이며 런타임에 자동 반영되지 않는다.

[D180의 종류별 필수 속성](../../docs/06-art-audio/asset-spec.md#종류별-필수-속성-기록--d180)을 누락한 어셋은 초안으로 남긴다. [현재 의자](items/chair/asset.json)는 착석·설치 연결 정보를 기록한 실제 등록 예이며 작성용 템플릿과 구분한다.
