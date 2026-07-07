migrate((app) => {
  const chapter1WeaponPrices = {
    common: { sword: 80 },
    rare: { sword: 220 },
    epic: { sword: 700 },
  }

  const chapter2WeaponPrices = {
    common: {
      dagger: 330,
      spear: 350,
      sword: 380,
      axe: 430,
      greatsword: 480,
    },
    rare: {
      dagger: 850,
      spear: 900,
      sword: 1000,
      axe: 1120,
      greatsword: 1250,
    },
    epic: {
      dagger: 2100,
      spear: 2250,
      sword: 2500,
      axe: 2800,
      greatsword: 3100,
    },
  }

  const fieldString = (record, field) => String(record.get(field) || "").trim()
  const compact = (value) => String(value || "").replace(/\s/g, "").toLowerCase()

  const inferWeaponType = (template) => {
    const explicit = fieldString(template, "weapon_type")
    if (explicit) return explicit

    const name = compact(fieldString(template, "name"))
    if (name.includes("대검") || name.includes("greatsword")) return "greatsword"
    if (name.includes("도끼") || name.includes("axe")) return "axe"
    if (name.includes("단검") || name.includes("dagger")) return "dagger"
    if (name.includes("창") || name.includes("spear")) return "spear"
    return "sword"
  }

  const isWeapon = (template) => {
    const pieceType = fieldString(template, "set_piece_type")
    const slot = fieldString(template, "equipment_slot")
    const weaponType = fieldString(template, "weapon_type")
    return pieceType === "weapon" || slot === "sword" || weaponType !== ""
  }

  const isChapter2Weapon = (template) => {
    const setKey = fieldString(template, "set_key")
    if (setKey) return true
    const imagePath = fieldString(template, "image_path")
    if (imagePath.includes("/chapter2/")) return true
    const name = compact(fieldString(template, "name"))
    return (
      name.includes("모험가") ||
      name.includes("광전사") ||
      name.includes("창술사") ||
      name.includes("도적") ||
      name.includes("견습기사")
    )
  }

  const updatedPrices = {}
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment"`, "", 3000, 0)

  for (const template of templates) {
    if (!isWeapon(template)) continue

    const rarity = fieldString(template, "rarity")
    const weaponType = inferWeaponType(template)
    const priceMap = isChapter2Weapon(template) ? chapter2WeaponPrices : chapter1WeaponPrices
    const price = priceMap[rarity]?.[weaponType]
    if (price === undefined) continue

    template.set("price_coin", price)
    app.save(template)
    updatedPrices[template.id] = price
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 3000, 0)
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    const price = updatedPrices[templateID]
    if (price === undefined) continue
    shopItem.set("price_coin", price)
    app.save(shopItem)
  }

  const offers = app.findRecordsByFilter(
    "daily_shop_offers",
    `is_active=true && is_purchased=false`,
    "",
    3000,
    0,
  )
  for (const offer of offers) {
    const templateID = String(offer.get("item_template") || "")
    const price = updatedPrices[templateID]
    if (price === undefined) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}, (app) => {
  // Keep live weapon price balance on rollback.
})
