const text = (record, field) => String(record.get(field) || "").trim()

migrate((app) => {
  const bonusCollection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const bonuses = app.findRecordsByFilter(
    "equipment_set_bonuses",
    `set_key="riftbreaker"`,
    "",
    100,
    0,
  )

  for (const bonus of bonuses) {
    app.delete(bonus)
  }

  const effects = [
    [3, "defense_percent", 12, "3세트: 방어력 +12%"],
    [3, "agility_percent", -10, "3세트: 민첩 -10%"],
    [4, "defense_shred_per_hit", 3, "4세트: 타격마다 적 방어력 3 감소 (최소 0)"],
  ]
  for (const [count, type, value, description] of effects) {
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

  const templates = app.findRecordsByFilter("item_templates", `set_key="riftbreaker"`, "", 100, 0)
  for (const template of templates) {
    const baseDescription = text(template, "description").split(". 3세트:")[0]
    template.set(
      "description",
      `${baseDescription}. 3세트: 방어력 +12%, 민첩 -10% / 4세트: 타격마다 적 방어력 3 감소 (최소 0)`,
    )
    app.save(template)
  }
}, (app) => {
  // Balance migrations remain applied on rollback to avoid restoring stale effects.
})
