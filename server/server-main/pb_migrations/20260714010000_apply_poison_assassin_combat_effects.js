const poisonAssassinEffects = [
  {
    count: 3,
    type: "defense_penetration_percent",
    value: 15,
    description: "3세트: 적 방어력 15% 감소",
  },
  {
    count: 4,
    type: "fixed_damage",
    value: 12,
    description: "4세트: 공격 시 고정 독 피해 12",
  },
]

const recordString = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "").trim()
  } catch (_) {
    return ""
  }
}

migrate((app) => {
  const collection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const bonusTypeField = collection.fields.getByName("bonus_type")
  let schemaChanged = false
  for (const value of ["defense_penetration_percent", "fixed_damage"]) {
    if (bonusTypeField.values.includes(value)) continue
    bonusTypeField.values.push(value)
    schemaChanged = true
  }
  if (schemaChanged) app.save(collection)

  const records = app.findRecordsByFilter("equipment_set_bonuses", "", "", 1000, 0)
  for (const record of records) {
    if (recordString(record, "set_key") !== "poison_assassin") continue
    record.set("is_active", false)
    app.save(record)
  }

  for (const effect of poisonAssassinEffects) {
    let record = null
    for (const candidate of records) {
      if (recordString(candidate, "set_key") !== "poison_assassin") continue
      if (Number(candidate.get("required_count") || 0) !== effect.count) continue
      if (recordString(candidate, "bonus_type") !== effect.type) continue
      record = candidate
      break
    }
    if (!record) record = new Record(collection)
    record.set("set_key", "poison_assassin")
    record.set("set_name", "맹독 암살자 세트")
    record.set("required_count", effect.count)
    record.set("bonus_type", effect.type)
    record.set("bonus_value", effect.value)
    record.set("description", effect.description)
    record.set("is_active", true)
    app.save(record)
  }

  const templates = app.findRecordsByFilter("item_templates", "", "", 5000, 0)
  for (const template of templates) {
    if (recordString(template, "set_key") !== "poison_assassin") continue
    const baseDescription = recordString(template, "description")
      .replace(/\s*3세트:.*$/u, "")
      .trim()
    template.set(
      "description",
      `${baseDescription} 3세트: 적 방어력 15% 감소 / 4세트: 공격 시 고정 독 피해 12`.trim(),
    )
    app.save(template)
  }
}, (app) => {
  // Live set records are preserved on rollback.
})
