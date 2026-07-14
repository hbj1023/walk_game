const legacyChapter2SetKeys = ["vanguard", "berserker", "sentinel", "shadow", "colossus"]

const stringValue = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "").trim()
  } catch (_) {
    return ""
  }
}

const isLegacyChapter2Epic = (template) => {
  if (stringValue(template, "item_type") !== "equipment") return false
  if (stringValue(template, "rarity") !== "epic") return false
  if (stringValue(template, "set_key") === "poison_assassin") return false

  const setKey = stringValue(template, "set_key")
  if (legacyChapter2SetKeys.includes(setKey)) return true

  const source = `${stringValue(template, "name")} ${stringValue(template, "image_path")}`.toLowerCase()
  return source.includes("/chapter2/") ||
    source.includes("모험가") ||
    source.includes("광전사") ||
    source.includes("창술사") ||
    source.includes("도적") ||
    source.includes("견습기사")
}

migrate((app) => {
  const templates = app.findRecordsByFilter("item_templates", "", "", 5000, 0)
  const disabledTemplateIDs = {}

  for (const template of templates) {
    if (!isLegacyChapter2Epic(template)) continue
    template.set("is_active", false)
    app.save(template)
    disabledTemplateIDs[template.id] = true
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  for (const shopItem of shopItems) {
    if (!disabledTemplateIDs[stringValue(shopItem, "item_template")]) continue
    shopItem.set("is_active", false)
    app.save(shopItem)
  }

  const offers = app.findRecordsByFilter("daily_shop_offers", "", "", 5000, 0)
  for (const offer of offers) {
    if (!disabledTemplateIDs[stringValue(offer, "item_template")]) continue
    offer.set("is_active", false)
    app.save(offer)
  }
}, (app) => {
  // Retired chapter 2 epic templates stay disabled on rollback.
})
