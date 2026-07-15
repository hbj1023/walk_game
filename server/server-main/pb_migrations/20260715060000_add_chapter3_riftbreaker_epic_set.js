const riftbreakerSet = [
  ["균열자 대검", "weapon", "sword", "greatsword", "assets/images/equipment/chapter3/ch3_epic_riftstone_greatsword.png", 0, 82, 6, -12, 1200],
  ["균열자 투구", "helmet", "helmet", "", "assets/images/equipment/chapter3/ch3_epic_riftstone_helmet.png", 220, 5, 24, 0, 650],
  ["균열자 갑옷", "armor", "armor", "", "assets/images/equipment/chapter3/ch3_epic_riftstone_armor.png", 340, 6, 46, -2, 850],
  ["균열자 장화", "shoes", "shoes", "", "assets/images/equipment/chapter3/ch3_epic_riftstone_boots.png", 150, 2, 17, 10, 650],
]

const riftbreakerEffects = [
  [3, "attack_percent", 12, "3세트: 공격력 +12%"],
  [4, "defense_penetration_percent", 30, "4세트: 적 방어력 30% 무시"],
]

const recordText = (record, field) => {
  try {
    return String(record.get(field) || "").trim()
  } catch (_) {
    return ""
  }
}

migrate((app) => {
  const templateCollection = app.findCollectionByNameOrId("item_templates")
  const bonusCollection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const templates = app.findRecordsByFilter("item_templates", "", "", 5000, 0)
  const bonuses = app.findRecordsByFilter("equipment_set_bonuses", "", "", 1000, 0)

  const bonusTypeField = bonusCollection.fields.getByName("bonus_type")
  if (!bonusTypeField.values.includes("defense_penetration_percent")) {
    bonusTypeField.values.push("defense_penetration_percent")
    app.save(bonusCollection)
  }

  for (const template of templates) {
    if (recordText(template, "set_key") !== "crusher") continue
    template.set("is_active", false)
    app.save(template)
  }

  for (const [name, piece, slot, weaponType, imagePath, hp, attack, defense, agility, price] of riftbreakerSet) {
    let template = templates.find((candidate) =>
      recordText(candidate, "set_key") === "riftbreaker" &&
      recordText(candidate, "set_piece_type") === piece &&
      recordText(candidate, "rarity") === "epic"
    )
    if (!template) {
      template = new Record(templateCollection)
      templates.push(template)
    }
    const stats = [
      hp ? `최대 HP +${hp}` : "",
      attack ? `공격력 ${attack > 0 ? "+" : ""}${attack}` : "",
      defense ? `방어력 ${defense > 0 ? "+" : ""}${defense}` : "",
      agility ? `민첩 ${agility > 0 ? "+" : ""}${agility}` : "",
    ].filter(Boolean).join(", ")
    template.set("name", name)
    template.set("item_type", "equipment")
    template.set("rarity", "epic")
    template.set("equipment_slot", slot)
    template.set("weapon_type", weaponType)
    template.set("set_key", "riftbreaker")
    template.set("set_piece_type", piece)
    template.set("base_hp", hp)
    template.set("base_attack", attack)
    template.set("base_defense", defense)
    template.set("base_agility", agility)
    template.set("price_coin", price)
    template.set("image_path", imagePath)
    template.set("description", `균열자 세트. ${stats}. 3세트: 공격력 +12% / 4세트: 적 방어력 30% 무시`)
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("is_active", true)
    app.save(template)
  }

  for (const [count, type, value, description] of riftbreakerEffects) {
    let bonus = bonuses.find((candidate) =>
      recordText(candidate, "set_key") === "riftbreaker" &&
      Number(candidate.get("required_count") || 0) === count
    )
    if (!bonus) {
      bonus = new Record(bonusCollection)
      bonuses.push(bonus)
    }
    bonus.set("set_key", "riftbreaker")
    bonus.set("set_name", "균열자 세트")
    bonus.set("required_count", count)
    bonus.set("bonus_type", type)
    bonus.set("bonus_value", value)
    bonus.set("description", description)
    bonus.set("is_active", true)
    app.save(bonus)
  }
}, (app) => {
  // Riftbreaker equipment remains available on rollback.
})
