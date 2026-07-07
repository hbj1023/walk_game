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

  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  if (shops.length === 0) return

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && is_active=true`,
    "",
    1000,
    0,
  )

  for (const template of templates) {
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

    for (const shop of shops) {
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
}, (app) => {
  // Keep live shop weapon visibility on rollback.
})