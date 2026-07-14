const crusherSet = [
  {
    name: "파쇄자 대검",
    slot: "sword",
    pieceType: "weapon",
    weaponType: "greatsword",
    hp: 0,
    attack: 62,
    defense: 0,
    agility: -8,
    price: 800,
    imagePath: "assets/images/equipment/chapter3/ch3_weapon_rare_greatsword.png",
  },
  {
    name: "파쇄자 투구",
    slot: "helmet",
    pieceType: "helmet",
    weaponType: "",
    hp: 160,
    attack: 4,
    defense: 14,
    agility: 0,
    price: 420,
    imagePath: "assets/images/equipment/chapter2/ch2_armor_rare_colossus_helmet.png",
  },
  {
    name: "파쇄자 갑옷",
    slot: "armor",
    pieceType: "armor",
    weaponType: "",
    hp: 240,
    attack: 4,
    defense: 28,
    agility: 0,
    price: 560,
    imagePath: "assets/images/equipment/chapter2/ch2_armor_rare_colossus_armor.png",
  },
  {
    name: "파쇄자 장화",
    slot: "shoes",
    pieceType: "shoes",
    weaponType: "",
    hp: 100,
    attack: 0,
    defense: 10,
    agility: 12,
    price: 420,
    imagePath: "assets/images/equipment/chapter2/ch2_armor_rare_colossus_boots.png",
  },
]

const crusherEffects = [
  { count: 3, type: "attack_percent", value: 8, description: "3세트: 공격력 +8%" },
  { count: 4, type: "defense_penetration_percent", value: 30, description: "4세트: 적 방어력 30% 무시" },
]

const stringValue = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "").trim()
  } catch (_) {
    return ""
  }
}

const findRecord = (records, predicate) => {
  for (const record of records) {
    if (predicate(record)) return record
  }
  return null
}

migrate((app) => {
  const templatesCollection = app.findCollectionByNameOrId("item_templates")
  const bonusesCollection = app.findCollectionByNameOrId("equipment_set_bonuses")

  const bonusTypeField = bonusesCollection.fields.getByName("bonus_type")
  if (!bonusTypeField.values.includes("defense_penetration_percent")) {
    bonusTypeField.values.push("defense_penetration_percent")
    app.save(bonusesCollection)
  }

  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 1, 0)
  const shop = shops.length > 0 ? shops[0] : null
  const templates = app.findRecordsByFilter("item_templates", "", "", 5000, 0)
  const shopItemsCollection = shop ? app.findCollectionByNameOrId("shop_items") : null

  for (const item of crusherSet) {
    let template = findRecord(
      templates,
      (candidate) => stringValue(candidate, "set_key") === "crusher" &&
        stringValue(candidate, "set_piece_type") === item.pieceType &&
        stringValue(candidate, "rarity") === "rare",
    )
    if (!template) {
      template = new Record(templatesCollection)
      templates.push(template)
    }

    const description = [
      `최대 HP +${item.hp}`,
      `공격력 ${item.attack >= 0 ? "+" : ""}${item.attack}`,
      `방어력 +${item.defense}`,
      `민첩 ${item.agility >= 0 ? "+" : ""}${item.agility}`,
      "3세트: 공격력 +8%",
      "4세트: 적 방어력 30% 무시",
    ].filter((line) => !line.endsWith("+0")).join(" / ")

    template.set("name", item.name)
    template.set("item_type", "equipment")
    template.set("rarity", "rare")
    template.set("equipment_slot", item.slot)
    template.set("weapon_type", item.weaponType)
    template.set("set_key", "crusher")
    template.set("set_piece_type", item.pieceType)
    template.set("base_hp", item.hp)
    template.set("base_attack", item.attack)
    template.set("base_defense", item.defense)
    template.set("base_agility", item.agility)
    template.set("price_coin", item.price)
    template.set("image_path", item.imagePath)
    template.set("description", description)
    template.set("recover_hp", 0)
    template.set("max_stack", 1)
    template.set("is_active", true)
    app.save(template)

    if (shop) {
      const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
      let shopItem = findRecord(
        shopItems,
        (candidate) => stringValue(candidate, "shop") === shop.id &&
          stringValue(candidate, "item_template") === template.id,
      )
      if (!shopItem) shopItem = new Record(shopItemsCollection)
      shopItem.set("shop", shop.id)
      shopItem.set("item_template", template.id)
      shopItem.set("price_coin", item.price)
      shopItem.set("stock_limit", 0)
      shopItem.set("is_active", true)
      app.save(shopItem)
    }
  }

  const bonuses = app.findRecordsByFilter("equipment_set_bonuses", "", "", 1000, 0)
  for (const effect of crusherEffects) {
    let bonus = findRecord(
      bonuses,
      (candidate) => stringValue(candidate, "set_key") === "crusher" &&
        Number(candidate.get("required_count") || 0) === effect.count,
    )
    if (!bonus) {
      bonus = new Record(bonusesCollection)
      bonuses.push(bonus)
    }
    bonus.set("set_key", "crusher")
    bonus.set("set_name", "파쇄자 세트")
    bonus.set("required_count", effect.count)
    bonus.set("bonus_type", effect.type)
    bonus.set("bonus_value", effect.value)
    bonus.set("description", effect.description)
    bonus.set("is_active", true)
    app.save(bonus)
  }
}, (app) => {
  // Live equipment records are preserved on rollback.
})
