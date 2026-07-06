migrate((app) => {
  const targetName = "부서진 검"
  const imagePath = "assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png"
  const priceCoin = 80
  const templatePrices = {}

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && equipment_slot="sword" && rarity="common" && is_active=true`,
    "",
    1000,
    0,
  )

  for (const template of templates) {
    const setKey = String(template.get("set_key") || "")
    const setPieceType = String(template.get("set_piece_type") || "")
    const weaponType = String(template.get("weapon_type") || "")

    if (setKey !== "") continue
    if (setPieceType !== "" && setPieceType !== "weapon") continue
    if (weaponType !== "" && weaponType !== "sword") continue

    template.set("name", targetName)
    template.set("base_hp", 0)
    template.set("base_attack", 5)
    template.set("base_defense", 0)
    template.set("base_agility", 0)
    template.set("recover_hp", 0)
    template.set("max_stack_quantity", 1)
    template.set("price_coin", priceCoin)
    template.set("image_path", imagePath)
    template.set("description", "금이 간 초급 무기입니다. 공격력 +5.")
    app.save(template)
    templatePrices[template.id] = priceCoin
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 1000, 0)
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    const price = templatePrices[templateID]
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
    const price = templatePrices[templateID]
    if (price === undefined) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}, (app) => {
  // Keep live tutorial weapon values on rollback.
})
