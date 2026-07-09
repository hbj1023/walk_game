const chapter2SetKeys = ["vanguard", "berserker", "sentinel", "shadow", "colossus"]
const chapter2ArmorSlots = ["helmet", "armor", "shoes"]

const getString = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "")
  } catch (_) {
    return ""
  }
}

const inferSetKey = (template) => {
  const existing = getString(template, "set_key").trim()
  if (chapter2SetKeys.includes(existing)) return existing

  const source = [
    getString(template, "image_path"),
    getString(template, "name"),
    getString(template, "description"),
  ].join(" ").toLowerCase()

  for (const setKey of chapter2SetKeys) {
    if (source.includes(setKey)) return setKey
  }
  return ""
}

const repairChapter2ArmorShopLines = (app) => {
  const normalShops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  const shopItems = app.findCollectionByNameOrId("shop_items")
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment" && is_active=true`, "", 5000, 0)

  for (const template of templates) {
    const slot = getString(template, "equipment_slot")
    if (!chapter2ArmorSlots.includes(slot)) continue

    const setKey = inferSetKey(template)
    if (!setKey) continue

    const pieceType = getString(template, "set_piece_type")
    let changed = false
    if (getString(template, "set_key") !== setKey) {
      template.set("set_key", setKey)
      changed = true
    }
    if (pieceType !== slot) {
      template.set("set_piece_type", slot)
      changed = true
    }
    if (changed) app.save(template)

    const rarity = getString(template, "rarity")
    if (rarity !== "common" && rarity !== "rare") continue

    for (const shop of normalShops) {
      const existing = app.findRecordsByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, "", 1, 0)
      const record = existing.length > 0 ? existing[0] : new Record(shopItems)
      record.set("shop", shop.id)
      record.set("item_template", template.id)
      record.set("price_coin", Number(template.get("price_coin") || 0))
      record.set("stock_limit", 0)
      record.set("purchase_limit_per_user", 0)
      record.set("is_active", true)
      app.save(record)
    }
  }
}

migrate((app) => {
  repairChapter2ArmorShopLines(app)
}, (app) => {
  // Keep repaired chapter 2 armor set keys and shop rows on rollback.
})
