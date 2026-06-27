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

  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 1, 0)
  if (shops.length === 0) {
    return
  }
  const shop = shops[0]

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && rarity="common" && equipment_slot!="" && is_active=true`,
    "equipment_slot,price_coin,name",
    100,
    0,
  )

  for (const template of templates) {
    upsertByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, {
      shop: shop.id,
      item_template: template.id,
      price_coin: Number(template.get("price_coin") || 0),
      is_active: true,
    })
  }
}, (app) => {
  // Keep live shop content on rollback.
})
