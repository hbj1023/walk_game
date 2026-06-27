migrate((app) => {
  const findFirstByFilter = (collectionName, filter) => {
    const records = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
    return records.length > 0 ? records[0] : null
  }

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

  const shop = findFirstByFilter("shops", `shop_type="normal" && is_active=true`) ||
    upsertByFilter("shops", `name="기본 상점"`, {
      name: "기본 상점",
      shop_type: "normal",
      is_active: true,
    })

  const weaponShopItems = [
    { name: "초급 검", active: true },
    { name: "레어 검", active: false },
    { name: "에픽 검", active: false },
  ]

  for (const item of weaponShopItems) {
    const template = findFirstByFilter(
      "item_templates",
      `name="${item.name}" && item_type="equipment" && equipment_slot="sword"`
    )
    if (!template) {
      continue
    }

    upsertByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, {
      shop: shop.id,
      item_template: template.id,
      price_coin: Number(template.get("price_coin") || 0),
      is_active: item.active,
    })
  }
}, (app) => {
  // Keep live shop content on rollback.
})
