const riftbreakerPieces = {
  sword: "weapon",
  helmet: "helmet",
  armor: "armor",
  shoes: "shoes",
}

const riftbreakerBonuses = [
  [3, "defense_percent", 12, "3세트: 방어력 +12%"],
  [3, "agility_percent", -10, "3세트: 민첩 -10%"],
  [4, "defense_shred_per_hit", 3, "4세트: 타격마다 적 방어력 3 감소 (최소 0)"],
]

const text = (record, field) => {
  try {
    return String(record.get(field) || "").trim()
  } catch (_) {
    return ""
  }
}

migrate((app) => {
  const templates = app.findRecordsByFilter(
    "item_templates",
    `rarity="epic" && is_active=true`,
    "",
    5000,
    0,
  ).filter((record) => text(record, "name").startsWith("균열자 "))

  if (templates.length !== 4) {
    throw new Error(`active riftbreaker epic template count=${templates.length}`)
  }

  const seenPieces = new Set()
  for (const template of templates) {
    const slot = text(template, "equipment_slot")
    const piece = riftbreakerPieces[slot]
    if (!piece || seenPieces.has(piece)) {
      throw new Error(`invalid riftbreaker slot=${slot}`)
    }
    seenPieces.add(piece)
    template.set("set_key", "riftbreaker")
    template.set("set_piece_type", piece)
    app.save(template)
  }

  const bonusCollection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const existing = app.findRecordsByFilter(
    "equipment_set_bonuses",
    `set_key="riftbreaker"`,
    "",
    100,
    0,
  )
  for (const record of existing) app.delete(record)

  for (const [count, type, value, description] of riftbreakerBonuses) {
    const bonus = new Record(bonusCollection)
    bonus.set("set_key", "riftbreaker")
    bonus.set("set_name", "균열자 세트")
    bonus.set("required_count", count)
    bonus.set("bonus_type", type)
    bonus.set("bonus_value", value)
    bonus.set("description", description)
    bonus.set("is_active", true)
    app.save(bonus)
  }

  console.log("[riftbreaker-set] repaired 4 equipment links and 3 bonuses")
}, (app) => {
  // Keep repaired live catalog links on rollback.
})
