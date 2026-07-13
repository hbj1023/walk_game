const chapter2PacingMonsters = [
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 210, attack: 24, defense: 5, agility: 8, rewardCoinMin: 230, rewardCoinMax: 310 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 290, attack: 32, defense: 7, agility: 7, rewardCoinMin: 300, rewardCoinMax: 400 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 390, attack: 42, defense: 9, agility: 10, rewardCoinMin: 390, rewardCoinMax: 520 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 520, attack: 54, defense: 12, agility: 9, rewardCoinMin: 500, rewardCoinMax: 660 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 760, attack: 72, defense: 16, agility: 8, rewardCoinMin: 900, rewardCoinMax: 1200 },
]

const previousChapter2PacingMonsters = [
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 320, attack: 22, defense: 6, agility: 8, rewardCoinMin: 260, rewardCoinMax: 340 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 470, attack: 30, defense: 8, agility: 7, rewardCoinMin: 330, rewardCoinMax: 430 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 650, attack: 39, defense: 11, agility: 10, rewardCoinMin: 430, rewardCoinMax: 560 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 900, attack: 50, defense: 15, agility: 9, rewardCoinMin: 560, rewardCoinMax: 720 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 1300, attack: 68, defense: 20, agility: 8, rewardCoinMin: 1150, rewardCoinMax: 1500 },
]

const chapter2EquipmentPrices = {
  common: {
    weapon: { dagger: 220, spear: 240, sword: 260, axe: 280, greatsword: 300 },
    armor: { helmet: 130, armor: 180, shoes: 130 },
  },
  rare: {
    weapon: { dagger: 420, spear: 440, sword: 460, axe: 500, greatsword: 540 },
    armor: { helmet: 180, armor: 240, shoes: 180 },
  },
  epic: {
    weapon: { dagger: 950 },
    armor: { helmet: 520, armor: 680, shoes: 520 },
  },
}

const previousChapter2EquipmentPrices = {
  rare: {
    weapon: { dagger: 520, spear: 540, sword: 560, axe: 600, greatsword: 640 },
    armor: { helmet: 240, armor: 300, shoes: 240 },
  },
}

const poisonAssassinSetKey = "poison_assassin"
const legacyChapter2SetKeys = ["vanguard", "berserker", "sentinel", "shadow", "colossus"]
const poisonAssassinEffects = [
  { count: 3, type: "agility_percent", value: 15, description: "3세트: 민첩 +15%" },
  { count: 3, type: "damage_taken_percent", value: -5, description: "3세트: 받는 피해 -5%" },
  { count: 4, type: "attack_distance_percent", value: -12, description: "4세트: 공격 필요 거리 -12%" },
  { count: 4, type: "boss_damage_percent", value: 12, description: "4세트: 보스 피해 +12%" },
]

const poisonAssassinItems = [
  {
    pieceType: "weapon",
    equipmentSlot: "sword",
    weaponType: "dagger",
    name: "맹독 암살자 단검",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_dagger.png",
    price: chapter2EquipmentPrices.epic.weapon.dagger,
    stats: { hp: 0, attack: 38, defense: 0, agility: 45 },
    description: "맹독 암살자 세트의 에픽 단검입니다. 공격력 +38, 민첩 +45.",
  },
  {
    pieceType: "helmet",
    equipmentSlot: "helmet",
    weaponType: "",
    name: "맹독 암살자 복면",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_helmet.png",
    price: chapter2EquipmentPrices.epic.armor.helmet,
    stats: { hp: 140, attack: 4, defense: 7, agility: 18 },
    description: "맹독 암살자 세트의 에픽 복면입니다. HP +140, 공격력 +4, 방어력 +7, 민첩 +18.",
  },
  {
    pieceType: "armor",
    equipmentSlot: "armor",
    weaponType: "",
    name: "맹독 암살자 갑옷",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_armor.png",
    price: chapter2EquipmentPrices.epic.armor.armor,
    stats: { hp: 210, attack: 6, defense: 24, agility: 14 },
    description: "맹독 암살자 세트의 에픽 갑옷입니다. HP +210, 공격력 +6, 방어력 +24, 민첩 +14.",
  },
  {
    pieceType: "shoes",
    equipmentSlot: "shoes",
    weaponType: "",
    name: "맹독 암살자 장화",
    image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_boots.png",
    price: chapter2EquipmentPrices.epic.armor.shoes,
    stats: { hp: 110, attack: 3, defense: 5, agility: 28 },
    description: "맹독 암살자 세트의 에픽 장화입니다. HP +110, 공격력 +3, 방어력 +5, 민첩 +28.",
  },
]

const ensureChapter2EquipmentSchema = (app) => {
  const ensureField = (collection, fieldName, createField) => {
    try {
      collection.fields.getByName(fieldName)
      return false
    } catch (_) {
      collection.fields.add(createField())
      return true
    }
  }

  const itemTemplates = app.findCollectionByNameOrId("item_templates")
  let itemTemplatesChanged = false
  itemTemplatesChanged = ensureField(
    itemTemplates,
    "set_key",
    () => new TextField({ name: "set_key", max: 80 }),
  ) || itemTemplatesChanged
  itemTemplatesChanged = ensureField(
    itemTemplates,
    "set_piece_type",
    () => new SelectField({
      name: "set_piece_type",
      maxSelect: 1,
      values: ["weapon", "helmet", "armor", "shoes"],
    }),
  ) || itemTemplatesChanged
  itemTemplatesChanged = ensureField(
    itemTemplates,
    "image_path",
    () => new TextField({ name: "image_path", max: 255 }),
  ) || itemTemplatesChanged
  if (itemTemplatesChanged) app.save(itemTemplates)

  let setBonuses
  try {
    setBonuses = app.findCollectionByNameOrId("equipment_set_bonuses")
  } catch (_) {
    setBonuses = new Collection({
      id: "pbc_2070306000",
      type: "base",
      name: "equipment_set_bonuses",
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: null,
      updateRule: null,
      deleteRule: null,
    })
  }

  let setBonusesChanged = setBonuses.id === ""
  setBonusesChanged = ensureField(
    setBonuses,
    "set_key",
    () => new TextField({ name: "set_key", max: 80 }),
  ) || setBonusesChanged
  setBonusesChanged = ensureField(
    setBonuses,
    "set_name",
    () => new TextField({ name: "set_name", max: 80 }),
  ) || setBonusesChanged
  setBonusesChanged = ensureField(
    setBonuses,
    "required_count",
    () => new NumberField({ name: "required_count", onlyInt: true }),
  ) || setBonusesChanged
  setBonusesChanged = ensureField(
    setBonuses,
    "bonus_type",
    () => new SelectField({
      name: "bonus_type",
      maxSelect: 1,
      values: [
        "attack_percent",
        "defense_percent",
        "hp_percent",
        "agility_percent",
        "damage_taken_percent",
        "monster_gauge_percent",
        "boss_damage_percent",
        "attack_distance_percent",
      ],
    }),
  ) || setBonusesChanged
  setBonusesChanged = ensureField(
    setBonuses,
    "bonus_value",
    () => new NumberField({ name: "bonus_value" }),
  ) || setBonusesChanged
  setBonusesChanged = ensureField(
    setBonuses,
    "description",
    () => new TextField({ name: "description", max: 255 }),
  ) || setBonusesChanged
  setBonusesChanged = ensureField(
    setBonuses,
    "is_active",
    () => new BoolField({ name: "is_active" }),
  ) || setBonusesChanged
  if (setBonusesChanged) app.save(setBonuses)
}

const getString = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "").trim()
  } catch (_) {
    return ""
  }
}

const isWeapon = (template) => {
  const slot = getString(template, "equipment_slot")
  const pieceType = getString(template, "set_piece_type")
  const weaponType = getString(template, "weapon_type")
  return slot === "sword" || pieceType === "weapon" || weaponType !== ""
}

const inferWeaponType = (template) => {
  const explicit = getString(template, "weapon_type")
  if (explicit) return explicit

  const source = `${getString(template, "name")} ${getString(template, "image_path")}`.toLowerCase()
  if (source.includes("greatsword")) return "greatsword"
  if (source.includes("axe")) return "axe"
  if (source.includes("spear")) return "spear"
  if (source.includes("dagger")) return "dagger"
  return "sword"
}

const equipmentPieceType = (template) => {
  const pieceType = getString(template, "set_piece_type")
  if (pieceType) return pieceType === "sword" ? "weapon" : pieceType
  if (isWeapon(template)) return "weapon"
  return getString(template, "equipment_slot")
}

const applyStageMonsterBalance = (app, updates) => {
  for (const update of updates) {
    const stages = app.findRecordsByFilter(
      "stages",
      `stage_no=${update.stageNo} && stage_type="${update.stageType}" && is_active=true`,
      "",
      1,
      0,
    )
    if (stages.length === 0) continue

    const stageMonsters = app.findRecordsByFilter(
      "stage_monsters",
      `stage="${stages[0].id}" && spawn_order=1`,
      "",
      1,
      0,
    )
    if (stageMonsters.length === 0) continue

    const monster = app.findRecordById("monsters", stageMonsters[0].get("monster"))
    if (!monster || monster.get("monster_type") !== update.monsterType) continue

    monster.set("hp", update.hp)
    monster.set("attack", update.attack)
    monster.set("defense", update.defense)
    monster.set("agility", update.agility)
    monster.set("reward_coin_min", update.rewardCoinMin)
    monster.set("reward_coin_max", update.rewardCoinMax)
    app.save(monster)
  }
}

const syncShopPricesForTemplates = (app, templatePrices) => {
  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  for (const shopItem of shopItems) {
    const price = templatePrices[String(shopItem.get("item_template") || "")]
    if (price === undefined) continue
    shopItem.set("price_coin", price)
    app.save(shopItem)
  }

  const offers = app.findRecordsByFilter("daily_shop_offers", `is_active=true && is_purchased=false`, "", 5000, 0)
  for (const offer of offers) {
    const price = templatePrices[String(offer.get("item_template") || "")]
    if (price === undefined) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}

const syncChapter2Prices = (app, prices) => {
  const updatedPrices = {}
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment" && is_active=true`, "", 5000, 0)
  for (const template of templates) {
    const setKey = getString(template, "set_key")
    const imagePath = getString(template, "image_path").toLowerCase()
    if (!setKey && !imagePath.includes("/chapter2/")) continue

    const rarity = getString(template, "rarity")
    const pieceType = equipmentPieceType(template)
    const weapon = pieceType === "weapon"
    const price = weapon
      ? prices[rarity]?.weapon?.[inferWeaponType(template)]
      : prices[rarity]?.armor?.[pieceType]
    if (!price) continue

    template.set("price_coin", price)
    app.save(template)
    updatedPrices[template.id] = price
  }
  syncShopPricesForTemplates(app, updatedPrices)
}

const disableLegacyChapter2EpicEquipment = (app, keepTemplateIDs) => {
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment" && rarity="epic"`, "", 5000, 0)
  const disabled = {}
  for (const template of templates) {
    if (keepTemplateIDs[template.id]) continue
    const setKey = getString(template, "set_key")
    if (!legacyChapter2SetKeys.includes(setKey)) continue

    template.set("is_active", false)
    app.save(template)
    disabled[template.id] = true
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  for (const shopItem of shopItems) {
    if (!disabled[String(shopItem.get("item_template") || "")]) continue
    shopItem.set("is_active", false)
    app.save(shopItem)
  }
}

const setBonusesActive = (app, setKey, active) => {
  const records = app.findRecordsByFilter("equipment_set_bonuses", `set_key="${setKey}"`, "", 100, 0)
  for (const record of records) {
    record.set("is_active", active)
    app.save(record)
  }
}

const upsertSetBonus = (app, setKey, setName, effect) => {
  const collection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const filter = `set_key="${setKey}" && required_count=${effect.count} && bonus_type="${effect.type}"`
  const existing = app.findRecordsByFilter("equipment_set_bonuses", filter, "", 1, 0)
  const record = existing.length > 0 ? existing[0] : new Record(collection)
  record.set("set_key", setKey)
  record.set("set_name", setName)
  record.set("required_count", effect.count)
  record.set("bonus_type", effect.type)
  record.set("bonus_value", effect.value)
  record.set("description", effect.description)
  record.set("is_active", true)
  app.save(record)
}

const setEffectText = () => {
  const three = poisonAssassinEffects
    .filter((effect) => effect.count === 3)
    .map((effect) => effect.description.replace(/^3세트:\s*/, ""))
    .join(" / ")
  const four = poisonAssassinEffects
    .filter((effect) => effect.count === 4)
    .map((effect) => effect.description.replace(/^4세트:\s*/, ""))
    .join(" / ")
  return `세트효과 - 3세트: ${three} | 4세트: ${four}`
}

const findPoisonAssassinTemplate = (app, definition) => {
  const exact = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && rarity="epic" && set_key="${poisonAssassinSetKey}" && set_piece_type="${definition.pieceType}"`,
    "",
    1,
    0,
  )
  if (exact.length > 0) return exact[0]

  if (definition.pieceType === "weapon") {
    const legacyShadow = app.findRecordsByFilter(
      "item_templates",
      `item_type="equipment" && rarity="epic" && set_key="shadow" && set_piece_type="weapon"`,
      "",
      1,
      0,
    )
    if (legacyShadow.length > 0) return legacyShadow[0]
  }

  return new Record(app.findCollectionByNameOrId("item_templates"))
}

const upsertPoisonAssassinSet = (app) => {
  const setName = "맹독 암살자 세트"
  const effectText = setEffectText()
  const keptTemplateIDs = {}
  const templatePrices = {}

  for (const definition of poisonAssassinItems) {
    const template = findPoisonAssassinTemplate(app, definition)
    template.set("name", definition.name)
    template.set("item_type", "equipment")
    template.set("equipment_slot", definition.equipmentSlot)
    template.set("weapon_type", definition.weaponType)
    template.set("set_key", poisonAssassinSetKey)
    template.set("set_piece_type", definition.pieceType)
    template.set("image_path", definition.image)
    template.set("rarity", "epic")
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("price_coin", definition.price)
    template.set("description", `${definition.description} ${effectText}`)
    template.set("is_active", true)
    template.set("base_hp", definition.stats.hp)
    template.set("base_attack", definition.stats.attack)
    template.set("base_defense", definition.stats.defense)
    template.set("base_agility", definition.stats.agility)
    app.save(template)

    keptTemplateIDs[template.id] = true
    templatePrices[template.id] = definition.price
  }

  setBonusesActive(app, poisonAssassinSetKey, false)
  for (const effect of poisonAssassinEffects) {
    upsertSetBonus(app, poisonAssassinSetKey, setName, effect)
  }

  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  const shopItems = app.findCollectionByNameOrId("shop_items")
  for (const shop of shops) {
    for (const templateID of Object.keys(keptTemplateIDs)) {
      const template = app.findRecordById("item_templates", templateID)
      const existing = app.findRecordsByFilter("shop_items", `shop="${shop.id}" && item_template="${templateID}"`, "", 1, 0)
      const shopItem = existing.length > 0 ? existing[0] : new Record(shopItems)
      shopItem.set("shop", shop.id)
      shopItem.set("item_template", templateID)
      shopItem.set("price_coin", Number(template.get("price_coin") || 0))
      shopItem.set("stock_limit", 0)
      shopItem.set("purchase_limit_per_user", 0)
      shopItem.set("is_active", true)
      app.save(shopItem)
    }
  }

  syncShopPricesForTemplates(app, templatePrices)
  disableLegacyChapter2EpicEquipment(app, keptTemplateIDs)
}

migrate((app) => {
  ensureChapter2EquipmentSchema(app)
  applyStageMonsterBalance(app, chapter2PacingMonsters)
  syncChapter2Prices(app, chapter2EquipmentPrices)
  upsertPoisonAssassinSet(app)
}, (app) => {
  applyStageMonsterBalance(app, previousChapter2PacingMonsters)
  syncChapter2Prices(app, previousChapter2EquipmentPrices)
})
