# GAME_CONTEXT

Last updated: 2026-07-01

이 문서는 Codex 새 스레드나 프로젝트 스레드에서 항상 먼저 읽어야 하는 게임 컨텍스트다.  
새 스테이지, 몬스터, 에셋, 밸런스, 서버 데이터, UI 작업을 할 때 이 문서를 기준으로 판단한다.

## 1. 한 줄 요약

중세 판타지 분위기의 걷기 RPG다.  
플레이어는 현실에서 걷고, 걸음/거리로 공격 기회를 얻고, 숲길을 따라 스테이지를 진행하며 몬스터를 쓰러뜨린다.

## 2. 현재 프로젝트 위치

- 실제 게임 프로젝트 루트: `C:\Users\hbj10\Documents\Codex\2026-06-27\dlr\work`
- Flutter 클라이언트: `client\client-main`
- Go + PocketBase 서버: `server\server-main`
- 몬스터 이미지: `client\client-main\assets\images\monsters`
- 배경 이미지: `client\client-main\assets\images\bg`
- 몬스터 이미지 매핑 코드: `client\client-main\lib\services\monster_asset_service.dart`
- 전투 스테이지 선택 화면: `client\client-main\lib\features\battle\pages\battle_stage_page.dart`
- 실제 전투 화면: `client\client-main\lib\features\battle\pages\battle_page.dart`
- PocketBase 마이그레이션: `server\server-main\pb_migrations`

## 3. 게임의 기본 방향

### 장르

- 모바일/웹 기반 걷기 RPG
- Flutter 클라이언트 + Go 서버 + PocketBase 데이터 구조
- 걷기, 공격권, 일반 전투, 보스 전투, 장비, 상점, 인벤토리, 레이드 기능이 있는 구조

### 핵심 플레이 감각

- 플레이어는 걷기를 통해 공격 기회를 얻는다.
- 전투는 몬스터와 1대1 구도로 진행된다.
- 스테이지를 클리어하면 다음 스테이지가 열린다.
- 보상은 코인, 경험치, 스탯 경험치, 장비/아이템으로 이어진다.
- 너무 복잡한 조작보다 "걸어서 성장하고, 전투로 확인하는" 흐름이 중요하다.

### 전체 톤

- 중세시대 판타지
- 숲길, 왕국 외곽, 오래된 길, 낡은 표지판, 이끼 낀 돌, 폐성/성문/수문장 같은 소재가 어울린다.
- 현대 도시, 연구소, 항구, 사이버펑크, 총기, SF 장비는 현재 방향과 맞지 않는다.
- 너무 어둡고 잔혹한 다크 판타지보다는, 모바일 RPG에 맞는 밝지만 모험감 있는 중세 판타지가 좋다.

## 4. 사용자가 직접 말한 중요한 설정

- 현재 스테이지/지역 감각은 "숲길"이다.
- 전체 컨셉은 "중세시대"다.
- 다음 스테이지를 만들고 싶다.
- 새 창에서 물어볼 때마다 맥락이 끊기는 문제가 있어, 이 내용을 프로젝트 안에 넣어두고 이어가고 싶다.
- 몬스터/에셋을 만들 때 너무 픽셀이 밀도 높게 채워지고 눈이 깨져 보이는 방향은 싫다.
- 에셋은 기존 게임 스타일과 맞아야 하고, 너무 복잡한 내부 디테일보다 큼직하고 읽히는 실루엣이 중요하다.

## 5. 현재 구현에서 확인된 구조

### 클라이언트

- Flutter 앱이다.
- `pubspec.yaml`에서 `assets/images/monsters/` 폴더 전체를 에셋으로 포함한다.
- 몬스터 이미지는 `MonsterAssetService.imageForMonster(name, stageNo)`로 고른다.
- 현재 몬스터 이미지 파일은 다음과 같다.
  - `green_goblin.png`
  - `red_goblin.png`
  - `purple_goblin.png`
  - `rain_goblin.png`
  - `boss_goblin.png`
  - `boss_golem.png`
- 전투 스테이지 화면은 서버에서 스테이지 목록을 받아오고, 몬스터 이름과 HP를 보여준다.
- 전투 스테이지 화면에는 기본 폴백 몬스터 이름/HP가 있다.
  - 1: 그린 고블린, HP 350
  - 2: 레드 고블린, HP 420
  - 3: 퍼플 고블린, HP 520
  - 4: 레인보우 고블린, HP 650
  - 5: 보스 고블린, HP 820
- 스테이지 선택 화면의 표시 ID는 현재 `1-${stageNo}` 방식이다.
  - 예: stageNo 1 -> `1-1`
  - stageNo 5 -> `1-5`
  - stageNo 6을 추가하면 그대로는 `1-6`으로 보일 가능성이 크다.
  - 다음 지역을 `2-1`처럼 보이게 만들려면 UI 표시 규칙을 따로 고쳐야 한다.

### 서버

- 서버는 Go로 작성되어 있다.
- PocketBase 컬렉션 기반으로 스테이지/몬스터/전투 데이터를 관리한다.
- 관련 컬렉션은 다음이 핵심이다.
  - `stages`
  - `monsters`
  - `stage_monsters`
  - `user_stage_progress`
  - `battles`
- 일반 스테이지 목록 API는 `/stages/normal`이다.
- 일반 전투 시작/공격/이탈 API와 보스 전투 API가 분리되어 있다.
- 스테이지 클리어 시 다음 일반 스테이지가 열리는 흐름이 있다.

### 서버 데이터 모델 핵심 필드

`stages`

- `stage_no`: 스테이지 번호
- `title`: 화면에 보이는 스테이지 이름
- `stage_type`: `normal` 또는 `boss`
- `monster_count`: 몬스터 수
- `recommended_distance_min_m`: 추천 거리 최소값
- `recommended_distance_max_m`: 추천 거리 최대값
- `is_active`: 활성 여부

`monsters`

- `name`: 화면에 보이는 몬스터 이름
- `monster_type`: `normal`, `boss`, `raid` 등
- `required_distance_min_m`: 몬스터와 싸우는 데 요구되는 거리 최소값
- `required_distance_max_m`: 몬스터와 싸우는 데 요구되는 거리 최대값
- `reward_coin_min`: 보상 코인 최소값
- `reward_coin_max`: 보상 코인 최대값
- `hp`: 체력
- `attack`: 공격력
- `defense`: 방어력
- `agility`: 민첩
- `is_active`: 활성 여부

`stage_monsters`

- `stage`: 연결할 스테이지 ID
- `monster`: 연결할 몬스터 ID
- `spawn_order`: 출현 순서
- `is_boss`: 보스 여부

## 6. 현재 콘텐츠 상태

### 현재 흐름

현재 구현/대화 기준으로 전투 콘텐츠는 고블린 계열 중심이다.  
그래서 다음 스테이지는 단순히 색만 다른 고블린을 더 추가하기보다, 실루엣이 확 바뀌는 몬스터가 필요하다.

### 현재 몬스터 계열

- 그린 고블린
- 레드 고블린
- 퍼플 고블린
- 레인보우 고블린
- 보스 고블린

### 현재 문제점

- 고블린 색상 변주만 계속되면 새 지역에 온 느낌이 약하다.
- 기존 몬스터 풀은 "중세 숲길"에는 맞지만, 다음 스테이지의 신선함은 부족하다.
- 새 몬스터는 고블린과 실루엣이 달라야 한다.
- 이미지 생성 시 픽셀 내부가 너무 촘촘하면 눈/얼굴이 깨진 것처럼 보인다.

## 7. 다음 스테이지 추천 결정

현재 가장 좋은 다음 스테이지 방향은 다음이다.

### 추천 이름

그늘버섯 숲

### 영어/내부 슬러그 후보

- `gloomcap_grove`
- `shadowcap_forest`
- `sporewood_path`

추천 내부 슬러그: `gloomcap_grove`

### 화면 표시명 후보

- `그늘버섯 숲`
- `그늘버섯 숲길`
- `그늘버섯 숲 - 6`
- `왕국 외곽림 - 6`
- `마녀의 숲길 - 6`

추천 표시명: `그늘버섯 숲 - 6`

### 왜 이 방향이 좋은가

- 현재 지역이 숲길이라 자연스럽게 이어진다.
- 중세 판타지 세계관과 잘 맞는다.
- 새 지역인데 기존 분위기에서 갑자기 튀지 않는다.
- 버섯/포자/이끼/낡은 표지판/폐허 같은 오브젝트를 넣기 쉽다.
- 고블린과 다른 실루엣의 몬스터를 만들 수 있다.
- 일반몹, 엘리트몹, 보스몹으로 확장하기 좋다.

## 8. 다음 지역 콘셉트 상세

### 지역 설정

왕국 외곽 숲길 안쪽에 있는 어두운 버섯 군락지다.  
원래는 마을과 성을 잇던 오래된 숲길이었지만, 습기와 포자가 퍼지면서 길이 변했다.  
나무 뿌리와 버섯이 돌길을 덮었고, 오래된 기사들의 표식과 부서진 방패가 남아 있다.

### 분위기

- 숲길의 연장선
- 빛이 조금 줄어든 깊은 숲
- 버섯과 이끼가 많음
- 오래된 중세 길/표지판/작은 석상
- 너무 공포스럽지 않게, "모험 중 만난 이상한 숲" 정도

### 배경 요소

- 큰 버섯 군락
- 이끼 낀 돌길
- 오래된 나무 다리
- 부서진 목책
- 작은 숲 제단
- 낡은 왕국 표지판
- 녹슨 투구나 방패
- 바닥에 희미한 포자 가루
- 낮은 안개
- 나무 사이로 들어오는 빛줄기

### 색감

- 짙은 초록
- 이끼색
- 어두운 갈색
- 탁한 보라색
- 버섯 갓의 붉은 갈색/황토색
- 포자 느낌의 연한 노랑/연두
- 포인트 컬러는 너무 네온처럼 가지 않는다.

### 피해야 할 방향

- 현대식 연구소
- 항구/도시/차량
- SF 포자 실험실
- 지나치게 공포스러운 좀비/괴물
- 너무 귀여운 버섯 마스코트
- 배경이 너무 어두워 캐릭터가 안 보이는 스타일

## 9. 다음 대표 몬스터 결정

### 1순위 몬스터

포자 버섯병사

### 영어/내부 이름 후보

- `Spore Shroom`
- `Spore Shroom Soldier`
- `Gloomcap Soldier`

추천 내부 파일명: `spore_shroom.png`

### 역할

- 다음 스테이지의 대표 일반몹
- 고블린 다음으로 처음 만나는 비고블린 몬스터
- 작고 빠르며, 방어는 낮지만 공격 템포가 조금 빠른 몬스터

### 외형

- 작은 버섯 몸통
- 버섯 갓이 투구처럼 보임
- 작은 나무창 또는 짧은 단검
- 조그만 나무 방패나 잎 방패
- 발은 짧고 둥글게
- 얼굴은 단순해야 함
- 눈은 큼직하고 깨끗한 픽셀 덩어리로 보여야 함

### 성격

- 귀엽기만 하면 안 된다.
- 초반 몬스터처럼 가볍지만 전투 의지가 있어야 한다.
- 무섭기보다는 약간 심술궂고 경계하는 느낌.

### 능력 콘셉트

현재 전투 시스템에 독/상태이상 시스템이 확실히 구현되어 있지 않으므로, 일단 능력은 기본 스탯으로 표현한다.

- HP: 고블린보다 조금 높거나 비슷
- 공격력: 이전 일반몹보다 소폭 증가
- 방어력: 낮음
- 민첩: 비교적 높음
- 보상 코인: 이전 스테이지보다 조금 증가
- 요구 거리: 이전 스테이지보다 증가

나중에 상태이상 시스템을 추가한다면 포자/독/둔화 기믹을 붙이기 좋다.

## 10. 다음 보스 후보

### 보스 이름

균사 기사장

### 영어/내부 이름 후보

- `Elder Spore Knight`
- `Mycelium Knight`
- `Gloomcap Warden`

추천 내부 파일명: `boss_spore_knight.png`

### 역할

- 그늘버섯 숲 지역의 보스
- 버섯병사들의 지휘관
- 오래된 왕국 기사 갑옷에 균사가 자란 형태

### 외형

- 낡은 중세 갑옷
- 갑옷 틈새에서 균사/버섯이 자람
- 한 손에는 녹슨 검 또는 창
- 한 손에는 이끼 낀 방패
- 머리/투구 위에 큰 버섯 갓
- 기존 보스 고블린보다 키가 크고 무거운 실루엣

### 능력 콘셉트

- HP 높음
- 방어 높음
- 공격력 중상
- 민첩 낮거나 중간
- 보상 높음
- 보스 입장권 시스템을 유지할지 결정 필요

## 11. 후보 몬스터 정리

| 우선순위 | 이름 | 내부 파일명 | 용도 | 장점 |
|---|---|---|---|---|
| 1 | 포자 버섯병사 | `spore_shroom.png` | 일반몹 | 실루엣이 새롭고 숲길 다음 지역에 잘 맞음 |
| 2 | 이끼 돌정령 | `moss_golem.png` | 느린 탱커몹 | 기존 보스 골렘과 세계관 연결 가능 |
| 3 | 그림자 박쥐 | `shadow_bat.png` | 빠른 일반몹 | 작은 이미지에서도 읽기 쉽고 속도형 몬스터로 좋음 |
| 4 | 균사 기사장 | `boss_spore_knight.png` | 지역 보스 | 중세 컨셉과 버섯 지역을 강하게 연결 |

## 12. 추천 스테이지 번호/구조

현재 코드가 `stage_no` 기반으로 진행되므로 가장 쉬운 구현은 다음이다.

### 쉬운 구현안

- stage_no: 6
- stage_type: `normal`
- title: `그늘버섯 숲 - 6`
- monster_count: 1
- monster: `포자 버섯병사`

이 경우 화면 ID는 현재 UI 규칙상 `1-6`처럼 보일 수 있다.

### 더 좋은 구현안

지역 구분을 살리고 싶다면 UI 표시 규칙을 바꾼다.

- 기존 숲길: `1-1` ~ `1-5`
- 그늘버섯 숲: `2-1`부터 시작

하지만 서버 모델에는 현재 `world_no` 같은 필드가 없으므로, 단기적으로는 stage_no 6을 쓰는 편이 안전하다.

## 13. 추천 밸런스 초안

주의: 라이브 DB의 실제 스탯과 코드 폴백 값이 다를 수 있다. 구현 전에는 PocketBase의 현재 `monsters` 값을 확인해야 한다.

### 코드 폴백 HP 기준 확장안

현재 클라이언트 폴백 HP 기준:

- stage 1: 350
- stage 2: 420
- stage 3: 520
- stage 4: 650
- boss stage 5: 820

이 기준으로 stage 6 일반몹은 다음 정도가 자연스럽다.

| 필드 | 추천값 |
|---|---:|
| hp | 760 |
| attack | 42 |
| defense | 10 |
| agility | 8 |
| required_distance_min_m | 3200 |
| required_distance_max_m | 4300 |
| reward_coin_min | 180 |
| reward_coin_max | 250 |
| recommended_distance_min_m | 3200 |
| recommended_distance_max_m | 4300 |

### 라이브 DB 스탯이 더 낮게 잡혀 있다면

현재 실제 DB의 stage 4 일반몹 HP가 200~300대라면 위 값은 너무 높다.  
그 경우에는 다음 규칙으로 잡는다.

- 이전 일반 스테이지 몬스터 HP의 1.15~1.25배
- 이전 일반 스테이지 몬스터 attack의 1.10~1.20배
- defense는 +1~+3
- agility는 이전보다 +1~+3
- 보상 코인은 이전보다 15~25% 증가
- 요구 거리는 이전보다 15~30% 증가

## 14. 에셋 스타일 가이드

### 전체 스타일

- 모바일 RPG용 픽셀 아트 느낌
- 기존 캐릭터/고블린과 같이 쓸 수 있는 단순하고 선명한 실루엣
- 너무 고해상도 일러스트처럼 보이면 안 됨
- 너무 촘촘한 픽셀 노이즈가 있으면 안 됨
- 내부 디테일보다 큰 색면과 뚜렷한 외곽선이 중요함

### 픽셀 밀도

사용자가 싫어한 방향:

- 픽셀이 밀도 높게 꽉 차 있음
- 얼굴 안에 작은 점/색 덩어리가 너무 많음
- 눈 주변이 깨진 것처럼 보임
- 작은 하이라이트나 노이즈 때문에 표정이 흐려짐

원하는 방향:

- 큰 픽셀 블록
- 굵은 외곽선
- 넓은 단색 영역
- 눈은 큰 단순 픽셀 덩어리 2개
- 얼굴은 비워두는 느낌
- 48x48 또는 64x64 게임 스프라이트를 크게 확대한 듯한 느낌

### 배경 제거용 생성 조건

몬스터 에셋을 생성할 때는 배경 제거가 쉽도록 다음 중 하나를 사용한다.

- 완전 투명 배경
- 또는 단색 크로마키 배경 `#ff00ff`

단, 몬스터 본체에는 `#ff00ff`가 들어가면 안 된다.

## 15. 포자 버섯병사 이미지 생성 프롬프트

이미지 생성이나 에셋 검색 시 사용할 기본 프롬프트:

```text
mobile fantasy RPG enemy sprite, medieval forest mushroom soldier, small spore shroom warrior, mushroom cap helmet, squat body, tiny wooden spear, small leaf shield, mildly hostile expression, front-facing idle battle pose, transparent background, chunky low-resolution pixel art, thick dark outline, broad flat color areas, sparse interior pixels, clean readable eyes, two large simple off-white pixel eyes, no tiny pupils, no noisy face texture, no dithering, no text, no logo, no watermark
```

좀 더 강하게 기존 문제를 피하는 프롬프트:

```text
Create a clean chunky pixel-art enemy sprite for a medieval walking RPG. Subject: Spore Shroom Soldier, a small mushroom warrior from a shadowy forest road. Use large square pixels, thick outline, simple face, two large readable eyes, broad flat colors, very little interior detail. The sprite must not look like a compressed noisy image. Avoid tiny speckles, dense dithering, broken eyes, tiny pupils, messy highlights, cute mascot expression, horror gore, modern clothing, sci-fi equipment. Transparent or solid #ff00ff background only.
```

## 16. 균사 기사장 이미지 생성 프롬프트

```text
medieval fantasy boss enemy sprite, Elder Spore Knight, old rusted knight armor overgrown with mycelium and small mushrooms, large mushroom cap helmet, mossy shield, corroded sword, front-facing battle pose, intimidating but not horror, mobile RPG pixel-art style, chunky low-resolution pixels, thick dark outline, broad flat color regions, clean readable silhouette, simple eyes, transparent background, no text, no logo, no watermark
```

## 17. 그늘버섯 숲 배경 생성 프롬프트

```text
medieval fantasy forest road battle background, shadowy mushroom grove, mossy stone path, old wooden signpost, broken medieval fence, giant mushrooms, soft mist, warm shafts of light through trees, mobile RPG background, readable foreground/midground, not too dark, no characters, no UI, no text, painterly pixel-friendly style
```

배경은 몬스터/플레이어가 잘 보여야 하므로 너무 어둡게 만들지 않는다.

## 18. 구현 체크리스트

### 에셋

- `client\client-main\assets\images\monsters\spore_shroom.png` 추가
- 보스까지 만들면 `client\client-main\assets\images\monsters\boss_spore_knight.png` 추가
- 새 배경을 만들면 `client\client-main\assets\images\bg\gloomcap_grove_battle_bg.png` 추가
- `pubspec.yaml`은 폴더 단위로 에셋을 포함하고 있으므로 보통 별도 수정은 필요 없다.

### 클라이언트 코드

`client\client-main\lib\services\monster_asset_service.dart`

- `sporeShroom` 상수 추가
- `bossSporeKnight` 상수 추가 가능
- 이름 매칭에 다음 키워드 추가
  - `포자`
  - `버섯`
  - `spore`
  - `shroom`
  - `gloomcap`
  - `균사`
  - `mycelium`

`client\client-main\lib\features\battle\pages\battle_stage_page.dart`

- `_kBattlePreloadAssets`에 새 몬스터 이미지를 추가하는 것을 고려
- stage 6 폴백 이름/HP를 추가할 수 있음
- stage 6 이상 맵 포인트는 자동 계산되지만, 보기 좋게 하려면 `_kStagePoints` 확장 고려
- `1-6` 표시가 싫으면 stage 표시 ID 계산 규칙 수정 필요

`client\client-main\lib\features\battle\pages\battle_page.dart`

- 전투 배경을 스테이지별로 바꾸려면 배경 선택 로직이 필요
- 현재 전투 화면이 하나의 배경을 공통 사용한다면, stageNo별 배경 매핑을 추가하는 것이 좋음

### 서버/PocketBase

새 마이그레이션 파일을 추가한다.

예시 이름:

```text
server\server-main\pb_migrations\20260701040000_seed_gloomcap_grove_stage.js
```

해야 할 일:

- `monsters`에 `포자 버섯병사` upsert
- `stages`에 `그늘버섯 숲 - 6` upsert
- `stage_monsters`에 stage 6과 몬스터 연결
- 나중에 보스까지 만들면 `균사 기사장`과 보스 스테이지 추가

## 19. 마이그레이션 초안

실제 구현 시 값은 라이브 밸런스 확인 후 조정한다.

```javascript
migrate((app) => {
  const upsertByFilter = (collectionName, filter, values) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const existing = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
    const record = existing.length > 0 ? existing[0] : new Record(collection)
    for (const [key, value] of Object.entries(values)) {
      record.set(key, value)
    }
    app.save(record)
    return record
  }

  const sporeShroom = upsertByFilter("monsters", `name="포자 버섯병사"`, {
    name: "포자 버섯병사",
    monster_type: "normal",
    required_distance_min_m: 3200,
    required_distance_max_m: 4300,
    reward_coin_min: 180,
    reward_coin_max: 250,
    hp: 760,
    attack: 42,
    defense: 10,
    agility: 8,
    is_active: true,
  })

  const stage6 = upsertByFilter("stages", `stage_no=6 && stage_type="normal"`, {
    stage_no: 6,
    title: "그늘버섯 숲 - 6",
    stage_type: "normal",
    monster_count: 1,
    recommended_distance_min_m: 3200,
    recommended_distance_max_m: 4300,
    is_active: true,
  })

  upsertByFilter("stage_monsters", `stage="${stage6.id}" && spawn_order=1`, {
    stage: stage6.id,
    monster: sporeShroom.id,
    spawn_order: 1,
    is_boss: false,
  })
}, (app) => {
  // Keep live game content on rollback.
})
```

## 20. 이름 후보 아카이브

### 지역명 후보

- 그늘버섯 숲
- 그늘버섯 숲길
- 포자숲 길목
- 이끼 낀 폐성길
- 왕국 외곽림
- 마녀의 숲길
- 버섯 군락지
- 어둑버섯 숲

현재 1순위: 그늘버섯 숲

### 몬스터명 후보

- 포자 버섯병사
- 스포어 슈룸
- 그늘버섯 병사
- 버섯 창병
- 이끼버섯 파수꾼

현재 1순위: 포자 버섯병사

### 보스명 후보

- 균사 기사장
- 그늘버섯 기사장
- 포자숲 수문장
- 이끼 갑옷 기사
- 고대 균사 기사

현재 1순위: 균사 기사장

## 21. 다음 작업 우선순위

1. `spore_shroom.png` 에셋 확정
2. `MonsterAssetService`에 새 몬스터 이미지 매핑 추가
3. stage 6 서버 마이그레이션 추가
4. 스테이지 선택 화면에서 stage 6 표시가 어색하지 않은지 확인
5. 전투 화면에서 새 몬스터 이미지가 잘 보이는지 확인
6. 가능하면 새 배경 `gloomcap_grove_battle_bg.png` 추가
7. 보스 확장 여부 결정

## 22. 새 Codex 스레드에서 첫 메시지로 붙일 요약

새 프로젝트 스레드에서 빠르게 이어갈 때는 아래를 붙이면 된다.

```text
이 프로젝트는 중세 판타지 걷기 RPG다. 실제 프로젝트 루트는 C:\Users\hbj10\Documents\Codex\2026-06-27\dlr\work 이고, Flutter 클라이언트와 Go/PocketBase 서버로 구성되어 있다.

현재 전투 콘텐츠는 숲길 분위기이고 고블린 계열 몬스터가 중심이다. 전체 컨셉은 중세시대다. 다음 스테이지는 숲길에서 자연스럽게 이어지는 "그늘버섯 숲"으로 잡고 싶다. 대표 일반몹은 "포자 버섯병사 / Spore Shroom"이고, 보스 후보는 "균사 기사장 / Elder Spore Knight"다.

에셋은 모바일 RPG 픽셀 아트 느낌이어야 한다. 너무 촘촘한 픽셀 노이즈, 깨진 눈, 과한 디테일은 피하고, 큰 픽셀 블록, 굵은 외곽선, 단순하고 읽히는 눈, 넓은 색면을 우선한다.

구현할 때는 GAME_CONTEXT.md를 먼저 읽고, client/client-main/lib/services/monster_asset_service.dart, client/client-main/lib/features/battle/pages/battle_stage_page.dart, server/server-main/pb_migrations를 확인한 뒤 작업해줘.
```

## 23. Codex에게 당부할 것

- 새 지역을 고를 때 현재 컨셉인 "중세 숲길"에서 너무 멀리 벗어나지 말 것.
- 사용자가 이미 말한 설정을 잊지 말 것.
- 에셋 생성 시 작은 눈 디테일과 촘촘한 노이즈를 피할 것.
- 구현 전에는 실제 repo의 현재 파일을 먼저 확인할 것.
- 서버 데이터와 클라이언트 폴백 값이 다를 수 있으니 밸런스는 라이브 DB 또는 마이그레이션을 확인하고 조정할 것.
- 새 스레드에서 맥락이 부족하면 이 파일을 먼저 읽고 이어갈 것.
