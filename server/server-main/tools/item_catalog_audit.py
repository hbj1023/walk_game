#!/usr/bin/env python3
"""Build a read-only item template cleanup report from a PocketBase SQLite DB."""

from __future__ import annotations

import argparse
import csv
import sqlite3
from collections import Counter
from pathlib import Path


REFERENCE_COLUMNS = {
    "owned_equipments": "item_template",
    "character_consumables": "item_template",
    "shop_items": "item_template",
    "daily_shop_offers": "item_template",
    "monster_drop_items": "item_template",
    "reward_logs": "reward_item_template",
}

OUTPUT_COLUMNS = [
    "recommendation", "reason", "id", "name", "item_type", "rarity",
    "equipment_slot", "weapon_type", "set_key", "set_piece_type",
    "image_path", "is_active", "total_references",
    *[f"refs_{table}" for table in REFERENCE_COLUMNS],
]


def table_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')}


def value(row: sqlite3.Row, column: str, default: object = "") -> object:
    return row[column] if column in row.keys() and row[column] is not None else default


def load_reference_counts(connection: sqlite3.Connection) -> dict[str, Counter[str]]:
    tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    counts: dict[str, Counter[str]] = {}
    for table, column in REFERENCE_COLUMNS.items():
        counter: Counter[str] = Counter()
        if table in tables and column in table_columns(connection, table):
            query = (
                f'SELECT "{column}", COUNT(*) FROM "{table}" '
                f'WHERE "{column}" IS NOT NULL AND "{column}" != \'\' GROUP BY "{column}"'
            )
            for template_id, count in connection.execute(query):
                counter[str(template_id)] = int(count)
        counts[table] = counter
    return counts


def classify(
    row: sqlite3.Row,
    refs: dict[str, int],
    names: Counter[str],
    images: Counter[str],
) -> tuple[str, str]:
    active = bool(value(row, "is_active", 0))
    total_refs = sum(refs.values())
    shop_refs = refs.get("shop_items", 0)
    non_shop_refs = total_refs - shop_refs
    name = str(value(row, "name")).strip()
    image = str(value(row, "image_path")).strip()
    duplicate = names[name] > 1 or (image and images[image] > 1)
    if not active and shop_refs > 0 and non_shop_refs == 0:
        return "연결 정리 후 삭제 후보", f"상점 연결 {shop_refs}개만 남음"
    if total_refs > 0:
        return "유지 권장", f"참조 기록 {total_refs}개"
    if active:
        return "검토 필요", "활성 아이템" + (", 중복 가능성 있음" if duplicate else "")
    if duplicate:
        return "삭제 후보", "비활성, 참조 없음, 이름 또는 이미지 중복"
    return "삭제 후보", "비활성, 참조 없음"


def build_rows(connection: sqlite3.Connection) -> list[dict[str, object]]:
    connection.row_factory = sqlite3.Row
    columns = table_columns(connection, "item_templates")
    if not columns:
        raise RuntimeError("item_templates table was not found")
    selected = [column for column in OUTPUT_COLUMNS if column in columns]
    if "id" not in selected:
        raise RuntimeError("item_templates.id column was not found")
    source_rows = list(connection.execute(
        f'SELECT {", ".join(selected)} FROM item_templates ORDER BY item_type, rarity, name'
    ))
    references = load_reference_counts(connection)
    names = Counter(str(value(row, "name")).strip() for row in source_rows if str(value(row, "name")).strip())
    images = Counter(str(value(row, "image_path")).strip() for row in source_rows if str(value(row, "image_path")).strip())
    results: list[dict[str, object]] = []
    for row in source_rows:
        template_id = str(value(row, "id"))
        ref_counts = {table: references[table][template_id] for table in REFERENCE_COLUMNS}
        recommendation, reason = classify(row, ref_counts, names, images)
        result: dict[str, object] = {
            "recommendation": recommendation,
            "reason": reason,
            "total_references": sum(ref_counts.values()),
        }
        for column in OUTPUT_COLUMNS:
            if column.startswith("refs_"):
                result[column] = ref_counts[column.removeprefix("refs_")]
            elif column not in result:
                result[column] = value(row, column)
        results.append(result)
    return results


def write_report(rows: list[dict[str, object]], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / "item-catalog-audit.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    summary = Counter(str(row["recommendation"]) for row in rows)
    markdown_path = output_dir / "item-catalog-audit.md"
    with markdown_path.open("w", encoding="utf-8") as handle:
        handle.write("# Item catalog audit\n\n")
        handle.write(f"- 전체: {len(rows)}개\n")
        for label in ("유지 권장", "검토 필요", "연결 정리 후 삭제 후보", "삭제 후보"):
            handle.write(f"- {label}: {summary[label]}개\n")
        handle.write("\n삭제 후보는 자동 삭제되지 않습니다. CSV에서 사용자가 최종 판단하세요.\n")
    print(f"CSV: {csv_path}")
    print(f"Summary: {markdown_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit item templates without modifying PocketBase data.")
    parser.add_argument("database", type=Path, help="Path to a copied PocketBase data.db")
    parser.add_argument("--output", type=Path, default=Path("reports/item-catalog"))
    args = parser.parse_args()
    if not args.database.is_file():
        parser.error(f"database does not exist: {args.database}")
    with sqlite3.connect(args.database) as connection:
        write_report(build_rows(connection), args.output)


if __name__ == "__main__":
    main()
