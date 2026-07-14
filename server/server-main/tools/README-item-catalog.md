# 아이템 카탈로그 정리

이 도구는 PocketBase DB를 수정하지 않고 아이템 정리 후보만 보고서로 만듭니다.

## 사용 순서

```bash
docker cp pocketbase:/pb/pb_data/data.db /tmp/pb-data.db
python3 server/server-main/tools/item_catalog_audit.py /tmp/pb-data.db
```

생성 파일:

- `reports/item-catalog/item-catalog-audit.csv`: 아이템별 상세 검토표
- `reports/item-catalog/item-catalog-audit.md`: 분류 개수 요약

## 분류 기준

- `유지 권장`: 보유 장비, 소모품, 상점, 드롭 또는 보상 기록에서 참조 중
- `검토 필요`: 참조는 없지만 현재 활성 상태
- `연결 정리 후 삭제 후보`: 비활성 상태이며 구형 상점 연결만 남아 있음
- `삭제 후보`: 비활성 상태이며 어느 관계에서도 참조되지 않음

`삭제 후보`는 자동 삭제되지 않습니다. CSV에서 이름, 이미지, 장, 등급을 직접 확인한 뒤 최종 결정해야 합니다.

## 정리 원칙

1. 운영 DB 원본이 아니라 복사본으로 보고서를 생성합니다.
2. 참조가 하나라도 있는 아이템은 삭제하지 않습니다.
3. 사용자가 삭제 대상을 확정한 뒤 별도 정리 마이그레이션을 만듭니다.
4. 데이터 정리가 끝난 다음에만 과거 마이그레이션을 기준 스냅샷으로 통합합니다.
