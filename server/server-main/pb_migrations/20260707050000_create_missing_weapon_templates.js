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
  if (fieldsChanged) app.save(itemTemplates)

  const normalShops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  const compact = (value) => String(value || "").replace(/\s/g, "")

  const upsertByFilter = (collectionName, filter, values) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const existing = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
    const record = existing.length > 0 ? existing[0] : new Record(collection)
    for (const [key, value] of Object.entries(values)) {
      record.set(key, value)
    }
    app.save(record)
    return record
  }

  const findFirst = (filters) => {
    for (const filter of filters) {
      const records = app.findRecordsByFilter("item_templates", filter, "", 1, 0)
      if (records.length > 0) return records[0]
    }
    return null
  }

  const syncShopItem = (template, active) => {
    for (const shop of normalShops) {
      upsertByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, {
        shop: shop.id,
        item_template: template.id,
        price_coin: Number(template.get("price_coin") || 0),
        stock_limit: 0,
        purchase_limit_per_user: 0,
        is_active: active,
      })
    }
  }

  const tutorialWeapons = [
    {
      rarity: "common",
      names: ["부서진검", "낡은검", "초급검", "초급 검"],
      name: "부서진 검",
      attack: 5,
      defense: 0,
      price: 80,
      image: "assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png",
      description: "금이 간 초급 무기입니다. 공격력 +5.",
      shopActive: true,
    },
    {
      rarity: "rare",
      names: ["일반검", "일반 검", "레어검", "레어 검"],
      name: "일반 검",
      attack: 12,
      defense: 1,
      price: 220,
      image: "assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png",
      description: "튜토리얼 후반용 기본 검입니다. 공격력 +12, 방어 +1.",
      shopActive: true,
    },
    {
      rarity: "epic",
      names: ["에픽검", "에픽 검"],
      name: "에픽 검",
      attack: 24,
      defense: 4,
      price: 700,
      image: "assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png",
      description: "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 검입니다. 공격력 +24, 방어 +4.",
      shopActive: false,
    },
  ]

  for (const weapon of tutorialWeapons) {
    const nameFilters = weapon.names.map((name) => `item_type="equipment" && rarity="${weapon.rarity}" && name="${name}"`)
    const template = findFirst([
      `item_type="equipment" && rarity="${weapon.rarity}" && set_key="" && equipment_slot="sword"`,
      ...nameFilters,
    ]) || new Record(itemTemplates)

    template.set("name", weapon.name)
    template.set("item_type", "equipment")
    template.set("equipment_slot", "sword")
    template.set("weapon_type", "sword")
    template.set("set_key", "")
    template.set("set_piece_type", "weapon")
    template.set("image_path", weapon.image)
    template.set("rarity", weapon.rarity)
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("price_coin", weapon.price)
    template.set("description", weapon.description)
    template.set("is_active", true)
    template.set("base_hp", 0)
    template.set("base_attack", weapon.attack)
    template.set("base_defense", weapon.defense)
    template.set("base_agility", 0)
    app.save(template)
    syncShopItem(template, weapon.shopActive)
  }

  const chapter2Rarities = {
    common: {
      label: "일반",
      oldLabel: "Common",
      price: 380,
      images: {
        sword: "assets/images/equipment/chapter2/ch2_weapon_sword.png",
        axe: "assets/images/equipment/chapter2/ch2_weapon_axe.png",
        spear: "assets/images/equipment/chapter2/ch2_weapon_spear.png",
        dagger: "assets/images/equipment/chapter2/ch2_weapon_dagger.png",
        greatsword: "assets/images/equipment/chapter2/ch2_weapon_colossus.png",
      },
      stats: {
        sword: { attack: 18, defense: 3, agility: 0 },
        axe: { attack: 24, defense: 0, agility: -4 },
        spear: { attack: 16, defense: 8, agility: 0 },
        dagger: { attack: 13, defense: 0, agility: 16 },
        greatsword: { attack: 30, defense: 0, agility: -9 },
      },
      shopActive: true,
    },
    rare: {
      label: "희귀",
      oldLabel: "Rare",
      price: 1000,
      images: {
        sword: "assets/images/equipment/chapter2/ch2_weapon_rare_sword.png",
        axe: "assets/images/equipment/chapter2/ch2_weapon_rare_axe.png",
        spear: "assets/images/equipment/chapter2/ch2_weapon_rare_spear.png",
        dagger: "assets/images/equipment/chapter2/ch2_weapon_rare_dagger.png",
        greatsword: "assets/images/equipment/chapter2/ch2_weapon_rare_greatsword.png",
      },
      stats: {
        sword: { attack: 28, defense: 5, agility: 0 },
        axe: { attack: 37, defense: 0, agility: -6 },
        spear: { attack: 25, defense: 12, agility: 0 },
        dagger: { attack: 20, defense: 0, agility: 25 },
        greatsword: { attack: 47, defense: 0, agility: -14 },
      },
      shopActive: true,
    },
    epic: {
      label: "에픽",
      oldLabel: "Epic",
      price: 2500,
      images: {
        sword: "assets/images/equipment/chapter2/ch2_weapon_rare_sword.png",
        axe: "assets/images/equipment/chapter2/ch2_weapon_rare_axe.png",
        spear: "assets/images/equipment/chapter2/ch2_weapon_rare_spear.png",
        dagger: "assets/images/equipment/chapter2/ch2_weapon_rare_dagger.png",
        greatsword: "assets/images/equipment/chapter2/ch2_weapon_rare_greatsword.png",
      },
      stats: {
        sword: { attack: 37, defense: 7, agility: 0 },
        axe: { attack: 49, defense: 0, agility: -8 },
        spear: { attack: 33, defense: 16, agility: 0 },
        dagger: { attack: 27, defense: 0, agility: 33 },
        greatsword: { attack: 62, defense: 0, agility: -18 },
      },
      shopActive: false,
    },
  }

  const chapter2Sets = [
    { key: "vanguard", oldName: "Vanguard", setName: "모험가 세트", weaponType: "sword", weaponName: "검", oldWeaponName: "Sword" },
    { key: "berserker", oldName: "Berserker", setName: "광전사 세트", weaponType: "axe", weaponName: "도끼", oldWeaponName: "Axe" },
    { key: "sentinel", oldName: "Sentinel", setName: "창술사 세트", weaponType: "spear", weaponName: "창", oldWeaponName: "Spear" },
    { key: "shadow", oldName: "Shadow", setName: "도적 세트", weaponType: "dagger", weaponName: "단검", oldWeaponName: "Dagger" },
    { key: "colossus", oldName: "Colossus", setName: "견습기사 세트", weaponType: "greatsword", weaponName: "대검", oldWeaponName: "Greatsword" },
  ]

  for (const [rarity, rarityConfig] of Object.entries(chapter2Rarities)) {
    for (const set of chapter2Sets) {
      const stats = rarityConfig.stats[set.weaponType]
      const oldName = `${rarityConfig.oldLabel} ${set.oldName} ${set.oldWeaponName}`
      const newName = `${rarityConfig.label} ${set.weaponName}`
      const template = findFirst([
        `item_type="equipment" && rarity="${rarity}" && set_key="${set.key}" && set_piece_type="weapon"`,
        `item_type="equipment" && rarity="${rarity}" && name="${oldName}"`,
      ]) || new Record(itemTemplates)

      template.set("name", newName)
      template.set("item_type", "equipment")
      template.set("equipment_slot", "sword")
      template.set("weapon_type", set.weaponType)
      template.set("set_key", set.key)
      template.set("set_piece_type", "weapon")
      template.set("image_path", rarityConfig.images[set.weaponType])
      template.set("rarity", rarity)
      template.set("recover_hp", 0)
      template.set("max_stack_quantity", 1)
      template.set("price_coin", rarityConfig.price)
      template.set("description", `${set.setName} ${set.weaponName}.`)
      template.set("is_active", true)
      template.set("base_hp", 0)
      template.set("base_attack", stats.attack)
      template.set("base_defense", stats.defense)
      template.set("base_agility", stats.agility)
      app.save(template)
      syncShopItem(template, rarityConfig.shopActive)
    }
  }

  const activeOffers = app.findRecordsByFilter("daily_shop_offers", `is_active=true && is_purchased=false`, "", 1000, 0)
  for (const offer of activeOffers) {
    const templateID = String(offer.get("item_template") || "")
    if (!templateID) continue
    let template = null
    try {
      template = app.findRecordById("item_templates", templateID)
    } catch (_) {
      template = null
    }
    if (!template) continue

    const price = Number(template.get("price_coin") || 0)
    if (price <= 0) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}, (app) => {
  // Keep created weapon templates on rollback.
})
