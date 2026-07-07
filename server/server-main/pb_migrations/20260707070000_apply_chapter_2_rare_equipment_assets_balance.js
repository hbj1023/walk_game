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

  const setInfo = {
    vanguard: {
      label: "모험가",
      weaponType: "sword",
      weaponName: "검",
      pieceNames: { helmet: "투구", armor: "갑옷", shoes: "장화" },
      armorAux: { helmet: "defense", armor: "defense", shoes: "defense" },
    },
    berserker: {
      label: "광전사",
      weaponType: "axe",
      weaponName: "도끼",
      pieceNames: { helmet: "투구", armor: "갑옷", shoes: "장화" },
      armorAux: { helmet: "attack", armor: "attack", shoes: "attack" },
    },
    sentinel: {
      label: "창술사",
      weaponType: "spear",
      weaponName: "창",
      pieceNames: { helmet: "투구", armor: "사슬갑옷", shoes: "장화" },
      armorAux: { helmet: "defense", armor: "defense", shoes: "agility" },
    },
    shadow: {
      label: "도적",
      weaponType: "dagger",
      weaponName: "단검",
      pieceNames: { helmet: "두건", armor: "가죽갑옷", shoes: "장화" },
      armorAux: { helmet: "agility", armor: "agility", shoes: "agility" },
    },
    colossus: {
      label: "견습기사",
      weaponType: "greatsword",
      weaponName: "대검",
      pieceNames: { helmet: "투구", armor: "갑옷", shoes: "장화" },
      armorAux: { helmet: "attack", armor: "defense", shoes: "attack" },
    },
  }

  const weaponStats = {
    sword: { attack: 28, defense: 5, agility: 0 },
    axe: { attack: 37, defense: 0, agility: -6 },
    spear: { attack: 25, defense: 12, agility: 0 },
    dagger: { attack: 20, defense: 0, agility: 25 },
    greatsword: { attack: 47, defense: 0, agility: -14 },
  }

  const armorBaseStats = {
    helmet: { hp: 125, attack: 0, defense: 0, agility: 0, price: 700 },
    armor: { hp: 185, attack: 0, defense: 16, agility: 0, price: 900 },
    shoes: { hp: 70, attack: 0, defense: 0, agility: 16, price: 700 },
  }

  const addAuxStat = (stats, stat, value) => {
    if (stat === "attack") stats.attack += value
    if (stat === "defense") stats.defense += value
    if (stat === "agility") stats.agility += value
  }

  const definitions = []
  for (const [setKey, set] of Object.entries(setInfo)) {
    const weapon = weaponStats[set.weaponType]
    definitions.push({
      setKey,
      pieceType: "weapon",
      equipmentSlot: "sword",
      weaponType: set.weaponType,
      name: `희귀 ${set.label} ${set.weaponName}`,
      image: `assets/images/equipment/chapter2/ch2_weapon_rare_${set.weaponType === "greatsword" ? "greatsword" : set.weaponType}.png`,
      price: 1000,
      stats: { hp: 0, attack: weapon.attack, defense: weapon.defense, agility: weapon.agility },
      description: `${set.label} 세트의 2장 희귀 ${set.weaponName}입니다. 공격력 +${weapon.attack}${weapon.defense ? `, 방어 +${weapon.defense}` : ""}${weapon.agility ? `, 민첩 ${weapon.agility > 0 ? "+" : ""}${weapon.agility}` : ""}.`,
    })

    for (const pieceType of ["helmet", "armor", "shoes"]) {
      const base = armorBaseStats[pieceType]
      const stats = {
        hp: base.hp,
        attack: base.attack,
        defense: base.defense,
        agility: base.agility,
      }
      addAuxStat(stats, set.armorAux[pieceType], 5)
      const pieceName = set.pieceNames[pieceType]
      const filePiece = pieceType === "shoes" ? "boots" : pieceType
      definitions.push({
        setKey,
        pieceType,
        equipmentSlot: pieceType,
        weaponType: "",
        name: `희귀 ${set.label} ${pieceName}`,
        image: `assets/images/equipment/chapter2/ch2_armor_rare_${setKey}_${filePiece}.png`,
        price: base.price,
        stats,
        description: `${set.label} 세트의 2장 희귀 ${pieceName}입니다. 최대 HP +${stats.hp}${stats.attack ? `, 공격 +${stats.attack}` : ""}${stats.defense ? `, 방어 +${stats.defense}` : ""}${stats.agility ? `, 민첩 +${stats.agility}` : ""}.`,
      })
    }
  }

  const compact = (value) => String(value || "").replace(/\s/g, "").toLowerCase()
  const fieldString = (record, fieldName) => {
    try {
      return String(record.get(fieldName) || "")
    } catch (_) {
      return ""
    }
  }

  const rareTemplates = app.findRecordsByFilter("item_templates", `item_type="equipment" && rarity="rare"`, "", 1000, 0)
  const findTemplate = (definition) => {
    for (const template of rareTemplates) {
      if (
        fieldString(template, "set_key") === definition.setKey &&
        fieldString(template, "set_piece_type") === definition.pieceType
      ) {
        return template
      }
    }

    const targetName = compact(definition.name)
    for (const template of rareTemplates) {
      const name = compact(fieldString(template, "name"))
      if (name === targetName) return template
    }

    return new Record(itemTemplates)
  }

  const normalShops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  const syncShopItem = (template, price) => {
    const shopItems = app.findCollectionByNameOrId("shop_items")
    for (const shop of normalShops) {
      const existing = app.findRecordsByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, "", 1, 0)
      const record = existing.length > 0 ? existing[0] : new Record(shopItems)
      record.set("shop", shop.id)
      record.set("item_template", template.id)
      record.set("price_coin", price)
      record.set("stock_limit", 0)
      record.set("purchase_limit_per_user", 0)
      record.set("is_active", true)
      app.save(record)
    }
  }

  const updatedPrices = {}
  for (const definition of definitions) {
    const template = findTemplate(definition)
    template.set("name", definition.name)
    template.set("item_type", "equipment")
    template.set("equipment_slot", definition.equipmentSlot)
    template.set("weapon_type", definition.weaponType)
    template.set("set_key", definition.setKey)
    template.set("set_piece_type", definition.pieceType)
    template.set("image_path", definition.image)
    template.set("rarity", "rare")
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("price_coin", definition.price)
    template.set("description", definition.description)
    template.set("is_active", true)
    template.set("base_hp", definition.stats.hp)
    template.set("base_attack", definition.stats.attack)
    template.set("base_defense", definition.stats.defense)
    template.set("base_agility", definition.stats.agility)
    app.save(template)

    updatedPrices[template.id] = definition.price
    syncShopItem(template, definition.price)
  }

  const offers = app.findRecordsByFilter("daily_shop_offers", `is_active=true && is_purchased=false`, "", 1000, 0)
  for (const offer of offers) {
    const templateID = String(offer.get("item_template") || "")
    const price = updatedPrices[templateID]
    if (price === undefined) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}, (app) => {
  // Keep chapter 2 rare equipment art and balance values on rollback.
})
