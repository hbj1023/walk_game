migrate((app) => {
  const chapter1EquipmentPrices = {
    common: { helmet: 60, armor: 80, shoes: 60, sword: 80 },
    rare: { helmet: 160, armor: 200, shoes: 160, sword: 220 },
    epic: { helmet: 550, armor: 650, shoes: 550, sword: 700 },
  }

  const chapter2EquipmentPrices = {
    common: { helmet: 260, armor: 340, shoes: 260, sword: 380 },
    rare: { helmet: 700, armor: 900, shoes: 700, sword: 1000 },
    epic: { helmet: 1700, armor: 2100, shoes: 1700, sword: 2500 },
  }

  const consumablePrices = {
    "초급회복물약": 40,
    "중급회복물약": 110,
    "고급회복물약": 240,
    "5스테이지보스입장권": 250,
  }

  const templatePrices = {}
  const templates = app.findRecordsByFilter("item_templates", `is_active=true`, "", 1000, 0)

  for (const template of templates) {
    const itemType = String(template.get("item_type") || "")
    const nameKey = String(template.get("name") || "").replace(/\s/g, "")

    if (itemType === "consumable") {
      const price = consumablePrices[nameKey]
      if (price !== undefined) {
        template.set("price_coin", price)
        app.save(template)
        templatePrices[template.id] = price
      }
      continue
    }

    if (itemType !== "equipment") {
      continue
    }

    const rarity = String(template.get("rarity") || "")
    const slot = String(template.get("equipment_slot") || "")
    const setKey = String(template.get("set_key") || "")
    const prices = setKey === "" ? chapter1EquipmentPrices : chapter2EquipmentPrices
    const price = prices[rarity]?.[slot]
    if (price === undefined) {
      templatePrices[template.id] = Number(template.get("price_coin") || 0)
      continue
    }

    template.set("price_coin", price)
    app.save(template)
    templatePrices[template.id] = price
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
  // Keep live economy values on rollback.
})
