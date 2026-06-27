migrate((app) => {
  const epicEquipmentTemplates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && rarity="epic"`,
    "",
    500,
    0
  )

  for (const template of epicEquipmentTemplates) {
    const shopItems = app.findRecordsByFilter(
      "shop_items",
      `item_template="${template.id}"`,
      "",
      500,
      0
    )
    for (const shopItem of shopItems) {
      shopItem.set("is_active", false)
      app.save(shopItem)
    }
  }
}, (app) => {
  // Keep epic equipment shop items disabled on rollback.
})
