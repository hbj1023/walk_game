const chapter1EpicItems = [
  {
    pieceType: "weapon",
    slot: "sword",
    weaponType: "sword",
    name: "에픽 검",
    image: "assets/images/equipment/chapter1/epic_green_brass_sword.png",
    price: 700,
    stats: { hp: 0, attack: 24, defense: 4, agility: 0 },
    description: "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 검입니다. 공격력 +24, 방어력 +4.",
  },
  {
    pieceType: "helmet",
    slot: "helmet",
    weaponType: "",
    name: "에픽 투구",
    image: "assets/images/equipment/chapter1/epic_green_brass_helmet.png",
    price: 380,
    stats: { hp: 80, attack: 0, defense: 0, agility: 0 },
    description: "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 투구입니다. HP +80.",
  },
  {
    pieceType: "armor",
    slot: "armor",
    weaponType: "",
    name: "에픽 갑옷",
    image: "assets/images/equipment/chapter1/epic_green_brass_armor.png",
    price: 430,
    stats: { hp: 0, attack: 0, defense: 14, agility: 0 },
    description: "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 갑옷입니다. 방어력 +14.",
  },
  {
    pieceType: "shoes",
    slot: "shoes",
    weaponType: "",
    name: "에픽 신발",
    image: "assets/images/equipment/chapter1/epic_green_brass_boots.png",
    price: 360,
    stats: { hp: 0, attack: 0, defense: 0, agility: 18 },
    description: "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 신발입니다. 민첩 +18.",
  },
]

const chapter2PoisonItems = [
  {
    pieceType: "weapon",
    slot: "sword",
    weaponType: "dagger",
    name: "맹독 암살자 단검",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_dagger.png",
    price: 950,
    stats: { hp: 0, attack: 38, defense: 0, agility: 45 },
    description: "맹독 암살자 세트의 에픽 단검입니다. 공격력 +38, 민첩 +45.",
  },
  {
    pieceType: "helmet",
    slot: "helmet",
    weaponType: "",
    name: "맹독 암살자 복면",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_helmet.png",
    price: 520,
    stats: { hp: 140, attack: 4, defense: 7, agility: 18 },
    description: "맹독 암살자 세트의 에픽 복면입니다. HP +140, 공격력 +4, 방어력 +7, 민첩 +18.",
  },
  {
    pieceType: "armor",
    slot: "armor",
    weaponType: "",
    name: "맹독 암살자 갑옷",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_armor.png",
    price: 680,
    stats: { hp: 210, attack: 6, defense: 24, agility: 14 },
    description: "맹독 암살자 세트의 에픽 갑옷입니다. HP +210, 공격력 +6, 방어력 +24, 민첩 +14.",
  },
  {
    pieceType: "shoes",
    slot: "shoes",
    weaponType: "",
    name: "맹독 암살자 장화",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_boots.png",
    price: 520,
    stats: { hp: 110, attack: 3, defense: 5, agility: 28 },
    description: "맹독 암살자 세트의 에픽 장화입니다. HP +110, 공격력 +3, 방어력 +5, 민첩 +28.",
  },
]

const textValue = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "").trim()
  } catch (_) {
    return ""
  }
}

const allEquipmentTemplates = (app) => app.findRecordsByFilter(
  "item_templates",
  'item_type="equipment"',
  "",
  5000,
  0,
)

const findTemplate = (templates, definition, setKey) => {
  for (const template of templates) {
    if (textValue(template, "image_path") === definition.image) return template
  }
  for (const template of templates) {
    if (textValue(template, "name") === definition.name) return template
  }
  for (const template of templates) {
    if (textValue(template, "rarity") !== "epic") continue
    if (textValue(template, "set_key") !== setKey) continue
    if (textValue(template, "set_piece_type") === definition.pieceType) return template
  }
  return null
}

const applyDefinition = (template, definition, setKey) => {
  template.set("name", definition.name)
  template.set("item_type", "equipment")
  template.set("equipment_slot", definition.slot)
  template.set("weapon_type", definition.weaponType)
  template.set("set_key", setKey)
  template.set("set_piece_type", definition.pieceType)
  template.set("image_path", definition.image)
  template.set("rarity", "epic")
  template.set("recover_hp", 0)
  template.set("max_stack_quantity", 1)
  template.set("price_coin", definition.price)
  template.set("description", definition.description)
  template.set("is_active", true)
  template.set("base_hp", definition.stats.hp)
  template.set("base_attack", definition.stats.attack)
  template.set("base_defense", definition.stats.defense)
  template.set("base_agility", definition.stats.agility)
}

const upsertDefinitions = (app, definitions, setKey) => {
  const collection = app.findCollectionByNameOrId("item_templates")
  const templates = allEquipmentTemplates(app)
  const canonicalIDs = {}
  const templatePrices = {}

  for (const definition of definitions) {
    let template = findTemplate(templates, definition, setKey)
    if (!template) {
      template = new Record(collection)
      templates.push(template)
    }
    applyDefinition(template, definition, setKey)
    app.save(template)
    canonicalIDs[template.id] = true
    templatePrices[template.id] = definition.price
  }

  return { canonicalIDs, templatePrices }
}

const ensureShopItems = (app, templatePrices) => {
  const shops = app.findRecordsByFilter("shops", 'shop_type="normal" && is_active=true', "", 100, 0)
  const collection = app.findCollectionByNameOrId("shop_items")
  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)

  for (const shop of shops) {
    for (const templateID of Object.keys(templatePrices)) {
      let item = null
      for (const candidate of shopItems) {
        if (textValue(candidate, "shop") !== shop.id) continue
        if (textValue(candidate, "item_template") !== templateID) continue
        item = candidate
        break
      }
      if (!item) {
        item = new Record(collection)
        shopItems.push(item)
      }
      item.set("shop", shop.id)
      item.set("item_template", templateID)
      item.set("price_coin", templatePrices[templateID])
      item.set("stock_limit", 0)
      item.set("purchase_limit_per_user", 0)
      item.set("is_active", true)
      app.save(item)
    }
  }
}

const disableMixedDuplicates = (app, canonicalIDs) => {
  const duplicateIDs = {}
  for (const template of allEquipmentTemplates(app)) {
    if (canonicalIDs[template.id]) continue
    if (textValue(template, "rarity") !== "epic") continue

    const name = textValue(template, "name")
    const image = textValue(template, "image_path")
    const setKey = textValue(template, "set_key")
    const mixedChapterEpic = name.startsWith("맹독 암살자") ||
      image.includes("epic_green_brass") ||
      image.includes("ch2_epic_poison_assassin") ||
      setKey === "poison_assassin"
    if (!mixedChapterEpic) continue

    template.set("is_active", false)
    app.save(template)
    duplicateIDs[template.id] = true
  }

  for (const item of app.findRecordsByFilter("shop_items", "", "", 5000, 0)) {
    if (!duplicateIDs[textValue(item, "item_template")]) continue
    item.set("is_active", false)
    app.save(item)
  }
}

migrate((app) => {
  const chapter1 = upsertDefinitions(app, chapter1EpicItems, "")
  const chapter2 = upsertDefinitions(app, chapter2PoisonItems, "poison_assassin")
  const canonicalIDs = { ...chapter1.canonicalIDs, ...chapter2.canonicalIDs }
  const templatePrices = { ...chapter1.templatePrices, ...chapter2.templatePrices }

  disableMixedDuplicates(app, canonicalIDs)
  ensureShopItems(app, templatePrices)
}, (app) => {
  // Canonical equipment records are preserved on rollback.
})
