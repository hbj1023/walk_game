migrate((app) => {
  const bonusCollection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const bonusTypeField = bonusCollection.fields.getByName("bonus_type")
  if (!bonusTypeField.values.includes("defense_shred_per_hit")) {
    bonusTypeField.values.push("defense_shred_per_hit")
    app.save(bonusCollection)
  }

  const bonuses = app.findRecordsByFilter(
    "equipment_set_bonuses",
    `set_key="riftbreaker" && required_count=4`,
    "",
    100,
    0,
  )
  for (const bonus of bonuses) {
    bonus.set("bonus_type", "defense_shred_per_hit")
    bonus.set("bonus_value", 10)
    bonus.set("description", "4세트: 타격마다 적 방어력 10 감소 (최대 3중첩)")
    bonus.set("is_active", true)
    app.save(bonus)
  }

  const templates = app.findRecordsByFilter("item_templates", `rarity="epic"`, "", 5000, 0)
  for (const template of templates) {
    if (!String(template.get("name") || "").startsWith("균열자 ")) continue
    const description = String(template.get("description") || "")
      .replace("4세트: 적 방어력 30% 무시", "4세트: 타격마다 적 방어력 10 감소 (최대 3중첩)")
    template.set("description", description)
    app.save(template)
  }
}, (app) => {
  // Riftbreaker defense shred remains active on rollback.
})
