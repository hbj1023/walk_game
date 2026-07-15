const riftbreakerItems = [
  {
    name: "균열자 대검",
    piece: "weapon",
    slot: "sword",
    weaponType: "greatsword",
    image: "assets/images/equipment/chapter3/ch3_epic_riftstone_greatsword.png",
    hp: 0,
    attack: 82,
    defense: 6,
    agility: -12,
    price: 1200,
  },
  {
    name: "균열자 투구",
    piece: "helmet",
    slot: "helmet",
    weaponType: "",
    image: "assets/images/equipment/chapter3/ch3_epic_riftstone_helmet.png",
    hp: 220,
    attack: 5,
    defense: 24,
    agility: 0,
    price: 650,
  },
  {
    name: "균열자 갑옷",
    piece: "armor",
    slot: "armor",
    weaponType: "",
    image: "assets/images/equipment/chapter3/ch3_epic_riftstone_armor.png",
    hp: 340,
    attack: 6,
    defense: 46,
    agility: -2,
    price: 850,
  },
  {
    name: "균열자 장화",
    piece: "shoes",
    slot: "shoes",
    weaponType: "",
    image: "assets/images/equipment/chapter3/ch3_epic_riftstone_boots.png",
    hp: 150,
    attack: 2,
    defense: 17,
    agility: 10,
    price: 650,
  },
]

const riftbreakerBonuses = [
  [3, "defense_percent", 12, "3세트: 방어력 +12%"],
  [3, "agility_percent", -10, "3세트: 민첩 -10%"],
  [4, "defense_shred_per_hit", 3, "4세트: 타격마다 적 방어력 3 감소 (최소 0)"],
]

const recordText = (record, field) => {
  try {
    return String(record.get(field) || "").trim()
  } catch (_) {
    return ""
  }
}

const ensureField = (collection, name, createField) => {
  try {
    collection.fields.getByName(name)
    return false
  } catch (_) {
    collection.fields.add(createField())
    return true
  }
}

migrate((app) => {
  const templateCollection = app.findCollectionByNameOrId("item_templates")
  let templateSchemaChanged = false
  templateSchemaChanged = ensureField(
    templateCollection,
    "set_key",
    () => new TextField({ name: "set_key", max: 80 }),
  ) || templateSchemaChanged
  templateSchemaChanged = ensureField(
    templateCollection,
    "set_piece_type",
    () => new SelectField({
      name: "set_piece_type",
      maxSelect: 1,
      values: ["weapon", "helmet", "armor", "shoes"],
    }),
  ) || templateSchemaChanged
  templateSchemaChanged = ensureField(
    templateCollection,
    "image_path",
    () => new TextField({ name: "image_path", max: 255 }),
  ) || templateSchemaChanged
  if (templateSchemaChanged) app.save(templateCollection)

  const bonusCollection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const bonusTypeField = bonusCollection.fields.getByName("bonus_type")
  if (!bonusTypeField.values.includes("defense_shred_per_hit")) {
    bonusTypeField.values.push("defense_shred_per_hit")
    app.save(bonusCollection)
  }

  const templates = app.findRecordsByFilter("item_templates", "", "", 5000, 0)
  const canonicalTemplates = []
  for (const item of riftbreakerItems) {
    const matches = templates.filter((candidate) =>
      recordText(candidate, "name") === item.name &&
      recordText(candidate, "rarity") === "epic"
    )
    const template = matches.length > 0 ? matches[0] : new Record(templateCollection)
    for (const duplicate of matches.slice(1)) {
      duplicate.set("is_active", false)
      app.save(duplicate)
    }

    const stats = [
      item.hp ? `최대 HP +${item.hp}` : "",
      item.attack ? `공격력 ${item.attack > 0 ? "+" : ""}${item.attack}` : "",
      item.defense ? `방어력 ${item.defense > 0 ? "+" : ""}${item.defense}` : "",
      item.agility ? `민첩 ${item.agility > 0 ? "+" : ""}${item.agility}` : "",
    ].filter(Boolean).join(", ")

    template.set("name", item.name)
    template.set("item_type", "equipment")
    template.set("rarity", "epic")
    template.set("equipment_slot", item.slot)
    template.set("weapon_type", item.weaponType)
    template.set("set_key", "riftbreaker")
    template.set("set_piece_type", item.piece)
    template.set("base_hp", item.hp)
    template.set("base_attack", item.attack)
    template.set("base_defense", item.defense)
    template.set("base_agility", item.agility)
    template.set("price_coin", item.price)
    template.set("image_path", item.image)
    template.set(
      "description",
      `균열자 세트. ${stats}. 3세트: 방어력 +12%, 민첩 -10% / 4세트: 타격마다 적 방어력 3 감소 (최소 0)`,
    )
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("is_active", true)
    app.save(template)
    canonicalTemplates.push({ template, price: item.price })
  }

  const existingBonuses = app.findRecordsByFilter(
    "equipment_set_bonuses",
    `set_key="riftbreaker"`,
    "",
    100,
    0,
  )
  for (const bonus of existingBonuses) app.delete(bonus)
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

  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  const shopItemCollection = app.findCollectionByNameOrId("shop_items")
  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  for (const shop of shops) {
    for (const entry of canonicalTemplates) {
      let shopItem = shopItems.find((candidate) =>
        recordText(candidate, "shop") === shop.id &&
        recordText(candidate, "item_template") === entry.template.id
      )
      if (!shopItem) {
        shopItem = new Record(shopItemCollection)
        shopItems.push(shopItem)
      }
      shopItem.set("shop", shop.id)
      shopItem.set("item_template", entry.template.id)
      shopItem.set("price_coin", entry.price)
      shopItem.set("stock_limit", 0)
      shopItem.set("is_active", true)
      app.save(shopItem)
    }
  }
}, (app) => {
  // Canonical chapter 3 epic equipment remains available on rollback.
})
