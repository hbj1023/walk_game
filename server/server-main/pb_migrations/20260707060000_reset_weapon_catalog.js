migrate((app) => {
  const itemTemplates = app.findCollectionByNameOrId("item_templates")
  let fieldsChanged = false

  const ensureTextField = (fieldName, max = 0) => {
    try {
      itemTemplates.fields.getByName(fieldName)
      return
    } catch (_) {}

    itemTemplates.fields.add(new TextField({ name: fieldName, max }))
    fieldsChanged = true
  }

  const ensureSelectField = (fieldName, values) => {
    try {
      const field = itemTemplates.fields.getByName(fieldName)
      for (const value of values) {
        if (!field.values.includes(value)) {
          field.values.push(value)
          fieldsChanged = true
        }
      }
      return
    } catch (_) {}

    itemTemplates.fields.add(new SelectField({
      name: fieldName,
      maxSelect: 1,
      values,
    }))
    fieldsChanged = true
  }

  ensureSelectField("equipment_slot", ["helmet", "armor", "sword", "shoes"])
  ensureSelectField("weapon_type", ["sword", "axe", "spear", "dagger", "greatsword"])
  ensureTextField("set_key", 80)
  ensureSelectField("set_piece_type", ["weapon", "helmet", "armor", "shoes"])
  ensureTextField("image_path", 255)
  for (const fieldName of ["base_hp", "base_attack", "base_defense", "base_agility"]) {
    try {
      const field = itemTemplates.fields.getByName(fieldName)
      if (field.min !== null) {
        field.min = null
        fieldsChanged = true
      }
    } catch (_) {}
  }
  if (fieldsChanged) app.save(itemTemplates)

  const weaponTypes = ["sword", "axe", "spear", "dagger", "greatsword"]
  const compact = (value) => String(value || "").replace(/\s/g, "").toLowerCase()
  const fieldString = (record, fieldName) => {
    try {
      return String(record.get(fieldName) || "")
    } catch (_) {
      return ""
    }
  }
  const isWeaponLike = (record) => {
    const itemType = fieldString(record, "item_type")
    if (itemType && itemType !== "equipment") return false
    const slot = fieldString(record, "equipment_slot")
    const pieceType = fieldString(record, "set_piece_type")
    const weaponType = fieldString(record, "weapon_type")
    const name = fieldString(record, "name")
    const nameKey = compact(name)
    const lowerName = name.toLowerCase()
    const hasWeaponName =
      Boolean(keyByAlias[nameKey]) ||
      nameKey.endsWith("검") ||
      nameKey.endsWith("도끼") ||
      nameKey.endsWith("창") ||
      nameKey.endsWith("단검") ||
      nameKey.endsWith("대검") ||
      lowerName.includes("sword") ||
      lowerName.includes("axe") ||
      lowerName.includes("spear") ||
      lowerName.includes("dagger") ||
      lowerName.includes("greatsword")
    return slot === "sword" ||
      pieceType === "weapon" ||
      weaponTypes.includes(weaponType) ||
      hasWeaponName
  }

  const canonicalWeapons = [
    {
      key: "ch1:common:sword",
      chapter: 1,
      name: "부서진 검",
      rarity: "common",
      setKey: "",
      weaponType: "sword",
      price: 80,
      shopActive: true,
      image: "assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png",
      stats: { hp: 0, attack: 5, defense: 0, agility: 0 },
      description: "금이 간 초급 무기입니다. 공격력 +5.",
      aliases: ["부서진검", "낡은검", "초급검", "초급 검"],
    },
    {
      key: "ch1:rare:sword",
      chapter: 1,
      name: "일반 검",
      rarity: "rare",
      setKey: "",
      weaponType: "sword",
      price: 220,
      shopActive: true,
      image: "assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png",
      stats: { hp: 0, attack: 12, defense: 1, agility: 0 },
      description: "튜토리얼 후반용 기본 검입니다. 공격력 +12, 방어 +1.",
      aliases: ["일반검", "레어검", "레어 검"],
    },
    {
      key: "ch1:epic:sword",
      chapter: 1,
      name: "에픽 검",
      rarity: "epic",
      setKey: "",
      weaponType: "sword",
      price: 700,
      shopActive: false,
      image: "assets/images/equipment/chapter1/epic_green_brass_sword.png",
      stats: { hp: 0, attack: 24, defense: 4, agility: 0 },
      description: "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 검입니다. 공격력 +24, 방어 +4.",
      aliases: ["에픽검"],
    },
    {
      key: "ch2:common:vanguard",
      chapter: 2,
      name: "모험가 검",
      rarity: "common",
      setKey: "vanguard",
      weaponType: "sword",
      price: 380,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_sword.png",
      stats: { hp: 0, attack: 18, defense: 3, agility: 0 },
      description: "모험가 세트의 2장 일반 검입니다. 공격력 +18, 방어 +3.",
      aliases: ["일반모험가검", "commonvanguardsword"],
    },
    {
      key: "ch2:common:berserker",
      chapter: 2,
      name: "광전사 도끼",
      rarity: "common",
      setKey: "berserker",
      weaponType: "axe",
      price: 380,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_axe.png",
      stats: { hp: 0, attack: 24, defense: 0, agility: -4 },
      description: "광전사 세트의 2장 일반 도끼입니다. 공격력 +24, 민첩 -4.",
      aliases: ["일반광전사도끼", "commonberserkeraxe", "일반도끼"],
    },
    {
      key: "ch2:common:sentinel",
      chapter: 2,
      name: "창술사 창",
      rarity: "common",
      setKey: "sentinel",
      weaponType: "spear",
      price: 380,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_spear.png",
      stats: { hp: 0, attack: 16, defense: 8, agility: 0 },
      description: "창술사 세트의 2장 일반 창입니다. 공격력 +16, 방어 +8.",
      aliases: ["일반창술사창", "commonsentinelspear", "일반창"],
    },
    {
      key: "ch2:common:shadow",
      chapter: 2,
      name: "도적 단검",
      rarity: "common",
      setKey: "shadow",
      weaponType: "dagger",
      price: 380,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_dagger.png",
      stats: { hp: 0, attack: 13, defense: 0, agility: 16 },
      description: "도적 세트의 2장 일반 단검입니다. 공격력 +13, 민첩 +16.",
      aliases: ["일반도적단검", "commonshadowdagger", "일반단검"],
    },
    {
      key: "ch2:common:colossus",
      chapter: 2,
      name: "견습기사 대검",
      rarity: "common",
      setKey: "colossus",
      weaponType: "greatsword",
      price: 380,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_colossus.png",
      stats: { hp: 0, attack: 30, defense: 0, agility: -9 },
      description: "견습기사 세트의 2장 일반 대검입니다. 공격력 +30, 민첩 -9.",
      aliases: ["일반견습기사대검", "commoncolossusgreatsword", "일반대검"],
    },
    {
      key: "ch2:rare:vanguard",
      chapter: 2,
      name: "희귀 모험가 검",
      rarity: "rare",
      setKey: "vanguard",
      weaponType: "sword",
      price: 1000,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_sword.png",
      stats: { hp: 0, attack: 28, defense: 5, agility: 0 },
      description: "모험가 세트의 2장 희귀 검입니다. 공격력 +28, 방어 +5.",
      aliases: ["희귀검", "희귀모험가검", "rarevanguardsword"],
    },
    {
      key: "ch2:rare:berserker",
      chapter: 2,
      name: "희귀 광전사 도끼",
      rarity: "rare",
      setKey: "berserker",
      weaponType: "axe",
      price: 1000,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_axe.png",
      stats: { hp: 0, attack: 37, defense: 0, agility: -6 },
      description: "광전사 세트의 2장 희귀 도끼입니다. 공격력 +37, 민첩 -6.",
      aliases: ["희귀도끼", "희귀광전사도끼", "rareberserkeraxe"],
    },
    {
      key: "ch2:rare:sentinel",
      chapter: 2,
      name: "희귀 창술사 창",
      rarity: "rare",
      setKey: "sentinel",
      weaponType: "spear",
      price: 1000,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_spear.png",
      stats: { hp: 0, attack: 25, defense: 12, agility: 0 },
      description: "창술사 세트의 2장 희귀 창입니다. 공격력 +25, 방어 +12.",
      aliases: ["희귀창", "희귀창술사창", "raresentinelspear"],
    },
    {
      key: "ch2:rare:shadow",
      chapter: 2,
      name: "희귀 도적 단검",
      rarity: "rare",
      setKey: "shadow",
      weaponType: "dagger",
      price: 1000,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_dagger.png",
      stats: { hp: 0, attack: 20, defense: 0, agility: 25 },
      description: "도적 세트의 2장 희귀 단검입니다. 공격력 +20, 민첩 +25.",
      aliases: ["희귀단검", "희귀도적단검", "rareshadowdagger"],
    },
    {
      key: "ch2:rare:colossus",
      chapter: 2,
      name: "희귀 견습기사 대검",
      rarity: "rare",
      setKey: "colossus",
      weaponType: "greatsword",
      price: 1000,
      shopActive: true,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_greatsword.png",
      stats: { hp: 0, attack: 47, defense: 0, agility: -14 },
      description: "견습기사 세트의 2장 희귀 대검입니다. 공격력 +47, 민첩 -14.",
      aliases: ["희귀대검", "희귀견습기사대검", "rarecolossusgreatsword"],
    },
    {
      key: "ch2:epic:vanguard",
      chapter: 2,
      name: "에픽 모험가 검",
      rarity: "epic",
      setKey: "vanguard",
      weaponType: "sword",
      price: 2500,
      shopActive: false,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_sword.png",
      stats: { hp: 0, attack: 37, defense: 7, agility: 0 },
      description: "모험가 세트의 2장 에픽 검입니다. 공격력 +37, 방어 +7.",
      aliases: ["에픽모험가검", "epicvanguardsword"],
    },
    {
      key: "ch2:epic:berserker",
      chapter: 2,
      name: "에픽 광전사 도끼",
      rarity: "epic",
      setKey: "berserker",
      weaponType: "axe",
      price: 2500,
      shopActive: false,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_axe.png",
      stats: { hp: 0, attack: 49, defense: 0, agility: -8 },
      description: "광전사 세트의 2장 에픽 도끼입니다. 공격력 +49, 민첩 -8.",
      aliases: ["에픽광전사도끼", "epicberserkeraxe"],
    },
    {
      key: "ch2:epic:sentinel",
      chapter: 2,
      name: "에픽 창술사 창",
      rarity: "epic",
      setKey: "sentinel",
      weaponType: "spear",
      price: 2500,
      shopActive: false,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_spear.png",
      stats: { hp: 0, attack: 33, defense: 16, agility: 0 },
      description: "창술사 세트의 2장 에픽 창입니다. 공격력 +33, 방어 +16.",
      aliases: ["에픽창술사창", "epicsentinelspear"],
    },
    {
      key: "ch2:epic:shadow",
      chapter: 2,
      name: "에픽 도적 단검",
      rarity: "epic",
      setKey: "shadow",
      weaponType: "dagger",
      price: 2500,
      shopActive: false,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_dagger.png",
      stats: { hp: 0, attack: 27, defense: 0, agility: 33 },
      description: "도적 세트의 2장 에픽 단검입니다. 공격력 +27, 민첩 +33.",
      aliases: ["에픽도적단검", "epicshadowdagger"],
    },
    {
      key: "ch2:epic:colossus",
      chapter: 2,
      name: "에픽 견습기사 대검",
      rarity: "epic",
      setKey: "colossus",
      weaponType: "greatsword",
      price: 2500,
      shopActive: false,
      image: "assets/images/equipment/chapter2/ch2_weapon_rare_greatsword.png",
      stats: { hp: 0, attack: 62, defense: 0, agility: -18 },
      description: "견습기사 세트의 2장 에픽 대검입니다. 공격력 +62, 민첩 -18.",
      aliases: ["에픽견습기사대검", "epiccolossusgreatsword"],
    },
  ]

  const canonicalByKey = {}
  const keyByAlias = {}
  for (const def of canonicalWeapons) {
    keyByAlias[compact(def.name)] = def.key
    for (const alias of def.aliases || []) {
      keyByAlias[compact(alias)] = def.key
    }
  }

  const weaponCatalogKey = (record) => {
    if (!isWeaponLike(record)) return ""
    const rarity = fieldString(record, "rarity")
    const setKey = fieldString(record, "set_key")
    const pieceType = fieldString(record, "set_piece_type")
    const weaponType = fieldString(record, "weapon_type")
    const slot = fieldString(record, "equipment_slot")

    if (setKey && (pieceType === "weapon" || slot === "sword" || weaponTypes.includes(weaponType))) {
      return `ch2:${rarity}:${setKey}`
    }

    const aliasKey = keyByAlias[compact(fieldString(record, "name"))]
    if (aliasKey) return aliasKey

    if (!setKey && (slot === "sword" || pieceType === "weapon" || weaponType === "sword")) {
      if (rarity === "common") return "ch1:common:sword"
      if (rarity === "rare") return "ch1:rare:sword"
      if (rarity === "epic") return "ch1:epic:sword"
    }
    return ""
  }

  const upsertShopItem = (shop, template, active) => {
    const collection = app.findCollectionByNameOrId("shop_items")
    const existing = app.findRecordsByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, "", 1, 0)
    const record = existing.length > 0 ? existing[0] : new Record(collection)
    record.set("shop", shop.id)
    record.set("item_template", template.id)
    record.set("price_coin", Number(template.get("price_coin") || 0))
    record.set("stock_limit", 0)
    record.set("purchase_limit_per_user", 0)
    record.set("is_active", active)
    app.save(record)
  }

  const allEquipmentTemplates = app.findRecordsByFilter("item_templates", `item_type="equipment"`, "", 2000, 0)
  const chosenTemplateIDs = {}
  for (const def of canonicalWeapons) {
    const candidates = allEquipmentTemplates.filter((record) => weaponCatalogKey(record) === def.key)
    let template = candidates.find((record) => compact(fieldString(record, "name")) === compact(def.name))
    if (!template) {
      template = candidates.find((record) => !chosenTemplateIDs[record.id])
    }
    if (!template) {
      template = new Record(itemTemplates)
    }

    template.set("name", def.name)
    template.set("item_type", "equipment")
    template.set("equipment_slot", "sword")
    template.set("weapon_type", def.weaponType)
    template.set("set_key", def.setKey)
    template.set("set_piece_type", "weapon")
    template.set("image_path", def.image)
    template.set("rarity", def.rarity)
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("price_coin", def.price)
    template.set("description", def.description)
    template.set("is_active", true)
    template.set("base_hp", def.stats.hp)
    template.set("base_attack", def.stats.attack)
    template.set("base_defense", def.stats.defense)
    template.set("base_agility", def.stats.agility)
    app.save(template)

    chosenTemplateIDs[template.id] = true
    canonicalByKey[def.key] = { def, template }
  }

  const canonicalIDByOldID = {}
  const oldWeaponIDs = {}
  const refreshedTemplates = app.findRecordsByFilter("item_templates", `item_type="equipment"`, "", 2000, 0)
  for (const template of refreshedTemplates) {
    if (!isWeaponLike(template)) continue
    const key = weaponCatalogKey(template)
    if (key && canonicalByKey[key] && canonicalByKey[key].template.id !== template.id) {
      canonicalIDByOldID[template.id] = canonicalByKey[key].template.id
    }
    if (!chosenTemplateIDs[template.id]) {
      oldWeaponIDs[template.id] = true
      if (template.get("is_active")) {
        template.set("is_active", false)
        app.save(template)
      }
    }
  }

  const normalShops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  for (const shop of normalShops) {
    for (const entry of Object.values(canonicalByKey)) {
      upsertShopItem(shop, entry.template, entry.def.shopActive)
    }
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 3000, 0)
  const canonicalTemplateDefs = {}
  for (const entry of Object.values(canonicalByKey)) {
    canonicalTemplateDefs[entry.template.id] = entry.def
  }
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    if (oldWeaponIDs[templateID]) {
      shopItem.set("is_active", false)
      app.save(shopItem)
      continue
    }
    const def = canonicalTemplateDefs[templateID]
    if (!def) continue
    const template = canonicalByKey[def.key].template
    shopItem.set("price_coin", def.price)
    shopItem.set("stock_limit", 0)
    shopItem.set("purchase_limit_per_user", 0)
    if (shopItem.get("is_active") !== def.shopActive) {
      shopItem.set("is_active", def.shopActive)
    }
    app.save(shopItem)
  }

  const remapRelation = (collectionName, relationField, options = {}) => {
    let records = []
    try {
      records = app.findRecordsByFilter(collectionName, "", "", 3000, 0)
    } catch (_) {
      return
    }
    for (const record of records) {
      const oldID = String(record.get(relationField) || "")
      const newID = canonicalIDByOldID[oldID]
      if (!newID) {
        if (options.deactivateOldWeapons && oldWeaponIDs[oldID]) {
          record.set("is_active", false)
          app.save(record)
        }
        continue
      }
      record.set(relationField, newID)
      const def = canonicalTemplateDefs[newID]
      if (def && options.syncPriceFields) {
        record.set("original_price_coin", def.price)
        record.set("price_coin", Math.floor(def.price * 0.9))
      }
      app.save(record)
    }
  }

  remapRelation("owned_equipments", "item_template")
  remapRelation("monster_drop_items", "item_template")
  remapRelation("daily_shop_offers", "item_template", { syncPriceFields: true, deactivateOldWeapons: true })
  remapRelation("reward_logs", "reward_item_template")
}, (app) => {
  // Keep the repaired weapon catalog on rollback.
})
