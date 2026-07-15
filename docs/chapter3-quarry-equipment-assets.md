# 3장 채석단 장비 에셋 적용표

원본 폴더: `equipment_concepts/chapter3_quarry_final_split_assets`

앱 저장 위치: `client/client-main/assets/images/equipment/chapter3`

## 세트 매핑

| 게임 세트 | 무기 | 방어구 에셋 키 |
| --- | --- | --- |
| 채석단 검사 | 검 | `vanguard` |
| 채석단 광전사 | 도끼 | `berserker` |
| 채석단 창술사 | 창 | `sentinel` |
| 채석단 도적 | 단검 | `shadow` |
| 채석단 기사 | 대검 | `colossus` |

## 파일 규칙

- 일반 무기: `ch3_weapon_{weapon}.png`
- 희귀 무기: `ch3_weapon_rare_{weapon}.png`
- 일반 방어구: `ch3_common_{armorKey}_{helmet|armor|boots}.png`
- 희귀 방어구: `ch3_rare_{armorKey}_{helmet|armor|boots}.png`

무기 10개는 기존 앱 파일과 제공 원본의 SHA-256 해시가 같아 교체하지 않았다. 방어구 30개는 제공 원본을 그대로 추가했으며, PocketBase `item_templates.image_path`는 `20260715040000_apply_chapter3_quarry_armor_images.js`에서 연결한다.
