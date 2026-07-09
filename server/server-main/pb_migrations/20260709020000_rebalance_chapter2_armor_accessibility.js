const chapter2SetKeys = ["vanguard", "berserker", "sentinel", "shadow", "colossus"]
const chapter2ArmorSlots = ["helmet", "armor", "shoes"]

const previousChapter2ArmorPrices = {
  common: { helmet: 260, armor: 340, shoes: 260 },
  rare: { helmet: 520, armor: 650, shoes: 520 },
  epic: { helmet: 1200, armor: 1500, shoes: 1200 },
}

const accessibleChapter2ArmorPrices = {
  common: { helmet: 200, armor: 240, shoes: 200 },
  rare: { helmet: 400, armor: 450, shoes: 400 },
  epic: { helmet: 900, armor: 1200, shoes: 900 },
}

const getString = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "")
  } catch (_) {
    return ""
  }
}

const syncChapter2ArmorPrices = (app, priceTable) => {
  const updatedTemplatePrices = {}
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment"`, "", 3000, 0)

  for (const template of templates) {
    const rarity = getString(template, "rarity")
    const setKey = getString(template, "set_key")
    const slot = getString(template, "equipment_slot")
    const pieceType = getString(template, "set_piece_type")

    if (!priceTable[rarity]) continue
    if (!chapter2SetKeys.includes(setKey)) continue
    if (!chapter2ArmorSlots.includes(slot)) continue
    if (pieceType && pieceType !== slot) continue

    const price = priceTable[rarity][slot]
    if (!price) continue

    template.set("price_coin", price)
    app.save(template)
    updatedTemplatePrices[template.id] = price
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    const price = updatedTemplatePrices[templateID]
    if (price === undefined) continue

    shopItem.set("price_coin", price)
    app.save(shopItem)
  }

  const offers = app.findRecordsByFilter("daily_shop_offers", `is_active=true && is_purchased=false`, "", 3000, 0)
  for (const offer of offers) {
    const templateID = String(offer.get("item_template") || "")
    const price = updatedTemplatePrices[templateID]
    if (price === undefined) continue

    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}

migrate((app) => {
  syncChapter2ArmorPrices(app, accessibleChapter2ArmorPrices)
}, (app) => {
  syncChapter2ArmorPrices(app, previousChapter2ArmorPrices)
})
