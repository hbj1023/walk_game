migrate((app) => {
  const equipmentPrices = {
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
    legendary: {
      helmet: 3600,
      armor: 4200,
      shoes: 3600,
      sword: 4500,
    },
    mythic: {
      helmet: 8000,
      armor: 9500,
      shoes: 8000,
      sword: 10000,
    },
  }

  const equipmentStats = {
    common: {
      helmet: { hp: 30 },
      armor: { defense: 4 },
      shoes: { agility: 6 },
      sword: { attack: 4 },
    },
    rare: {
      helmet: { hp: 70 },
      armor: { defense: 9 },
      shoes: { agility: 14 },
      sword: { attack: 10 },
    },
    epic: {
      helmet: { hp: 120 },
      armor: { defense: 18 },
      shoes: { agility: 24 },
      sword: { attack: 20 },
    },
    legendary: {
      helmet: { hp: 190 },
      armor: { defense: 30 },
      shoes: { agility: 38 },
      sword: { attack: 32 },
    },
    mythic: {
      helmet: { hp: 280 },
      armor: { defense: 46 },
      shoes: { agility: 56 },
      sword: { attack: 50 },
    },
  }

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && is_active=true`,
    "",
    500,
    0,
  )

  for (const template of templates) {
    const rarity = template.get("rarity")
    const slot = template.get("equipment_slot")
    const price = equipmentPrices[rarity]?.[slot]
    const stats = equipmentStats[rarity]?.[slot]
    if (!price || !stats) continue

    template.set("price_coin", price)
    template.set("base_hp", stats.hp || 0)
    template.set("base_attack", stats.attack || 0)
    template.set("base_defense", stats.defense || 0)
    template.set("base_agility", stats.agility || 0)
    template.set("recover_hp", 0)
    app.save(template)
  }

  const consumableUpdates = [
    { name: "초급 회복 물약", price: 60 },
    { name: "중급 회복 물약", price: 160 },
    { name: "고급 회복 물약", price: 360 },
    { name: "5스테이지 보스 입장권", price: 900 },
  ]

  for (const update of consumableUpdates) {
    const records = app.findRecordsByFilter(
      "item_templates",
      `name="${update.name}" && item_type="consumable"`,
      "",
      1,
      0,
    )
    if (records.length === 0) continue
    const template = records[0]
    template.set("price_coin", update.price)
    app.save(template)
  }

  const shopItems = app.findRecordsByFilter("shop_items", `is_active=true`, "", 500, 0)
  for (const shopItem of shopItems) {
    const templateID = shopItem.get("item_template")
    if (!templateID) continue
    let template
    try {
      template = app.findRecordById("item_templates", templateID)
    } catch (_) {
      continue
    }
    shopItem.set("price_coin", Number(template.get("price_coin") || 0))
    app.save(shopItem)
  }
}, (app) => {
  // Keep live economy values on rollback.
})
