migrate((app) => {
  const chapter1EquipmentPrices = {
    common: {
      helmet: 180,
      armor: 220,
      shoes: 180,
      sword: 220,
    },
    rare: {
      helmet: 600,
      armor: 720,
      shoes: 600,
      sword: 720,
    },
    epic: {
      helmet: 1500,
      armor: 1700,
      shoes: 1500,
      sword: 1800,
    },
  }

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && is_active=true`,
    "",
    1000,
    0,
  )

  const templatePrices = {}
  for (const template of templates) {
    const setKey = String(template.get("set_key") || "")
    const rarity = String(template.get("rarity") || "")
    const slot = String(template.get("equipment_slot") || "")
    const chapter1Price = chapter1EquipmentPrices[rarity]?.[slot]

    if (setKey === "" && chapter1Price) {
      template.set("price_coin", chapter1Price)
      app.save(template)
      templatePrices[template.id] = chapter1Price
      continue
    }

    templatePrices[template.id] = Number(template.get("price_coin") || 0)
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 1000, 0)
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    const price = templatePrices[templateID]
    if (price === undefined) continue
    shopItem.set("price_coin", price)
    app.save(shopItem)
  }
}, (app) => {
  // Keep live economy values on rollback.
})
