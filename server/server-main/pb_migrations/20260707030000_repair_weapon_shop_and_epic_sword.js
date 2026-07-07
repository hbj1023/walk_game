migrate((app) => {
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

  const normalShops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  const compact = (value) => String(value || "").replace(/\s/g, "")
  const fixedTemplatePrices = {}

  const epicTemplates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && rarity="epic" && is_active=true`,
    "",
    1000,
    0,
  )
  for (const template of epicTemplates) {
    const nameKey = compact(template.get("name"))
    const setKey = String(template.get("set_key") || "")
    const imagePath = String(template.get("image_path") || "")
    const priceCoin = Number(template.get("price_coin") || 0)
    const isChapter1EpicSword =
      nameKey === "에픽검" &&
      (setKey === "" || imagePath.includes("/chapter1/") || priceCoin <= 1000)
    if (!isChapter1EpicSword) continue

    template.set("name", "에픽 검")
    template.set("item_type", "equipment")
    template.set("equipment_slot", "sword")
    template.set("weapon_type", "sword")
    template.set("set_key", "")
    template.set("set_piece_type", "weapon")
    template.set("base_hp", 0)
    template.set("base_attack", 24)
    template.set("base_defense", 4)
    template.set("base_agility", 0)
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("price_coin", 700)
    template.set("image_path", "assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png")
    template.set("description", "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 검입니다. 공격력 +24, 방어 +4.")
    template.set("is_active", true)
    app.save(template)
    fixedTemplatePrices[template.id] = 700
  }

  const weaponTemplates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && is_active=true`,
    "",
    1000,
    0,
  )
  for (const template of weaponTemplates) {
    const rarity = String(template.get("rarity") || "")
    if (rarity !== "common" && rarity !== "rare") continue

    const equipmentSlot = String(template.get("equipment_slot") || "")
    const setPieceType = String(template.get("set_piece_type") || "")
    const weaponType = String(template.get("weapon_type") || "")
    const isWeapon = equipmentSlot === "sword" || setPieceType === "weapon"
    if (!isWeapon) continue

    if (equipmentSlot !== "sword") template.set("equipment_slot", "sword")
    if (setPieceType !== "weapon") template.set("set_piece_type", "weapon")
    if (weaponType === "") template.set("weapon_type", "sword")
    app.save(template)

    for (const shop of normalShops) {
      upsertByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, {
        shop: shop.id,
        item_template: template.id,
        price_coin: Number(template.get("price_coin") || 0),
        stock_limit: 0,
        purchase_limit_per_user: 0,
        is_active: true,
      })
    }
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 1000, 0)
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    const price = fixedTemplatePrices[templateID]
    if (price === undefined) continue
    shopItem.set("price_coin", price)
    app.save(shopItem)
  }

  const offers = app.findRecordsByFilter(
    "daily_shop_offers",
    `is_active=true && is_purchased=false`,
    "",
    1000,
    0,
  )
  for (const offer of offers) {
    const templateID = String(offer.get("item_template") || "")
    const price = fixedTemplatePrices[templateID]
    if (price === undefined) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}, (app) => {
  // Keep live weapon shop and epic sword repairs on rollback.
})