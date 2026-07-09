const chapter2SetKeys = ["vanguard", "berserker", "sentinel", "shadow", "colossus"]
const setKeyByWeaponType = {
  sword: "vanguard",
  axe: "berserker",
  spear: "sentinel",
  dagger: "shadow",
  greatsword: "colossus",
}

const rareChapter2Prices = {
  weapon: {
    dagger: 520,
    spear: 540,
    sword: 560,
    axe: 600,
    greatsword: 640,
  },
  armor: {
    helmet: 240,
    armor: 300,
    shoes: 240,
  },
}

const previousRareChapter2Prices = {
  weapon: {
    dagger: 850,
    spear: 900,
    sword: 1000,
    axe: 1120,
    greatsword: 1250,
  },
  armor: {
    helmet: 400,
    armor: 450,
    shoes: 400,
  },
}

const getString = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "").trim()
  } catch (_) {
    return ""
  }
}

const compact = (value) => String(value || "").replace(/\s/g, "").toLowerCase()

const hasChapter2Marker = (template) => {
  const source = [
    getString(template, "image_path"),
    getString(template, "name"),
    getString(template, "description"),
  ].join(" ").toLowerCase()

  if (source.includes("/chapter2/")) return true
  return chapter2SetKeys.some((setKey) => source.includes(setKey))
}

const inferWeaponType = (template) => {
  const explicit = getString(template, "weapon_type")
  if (explicit) return explicit

  const name = compact(getString(template, "name"))
  const image = compact(getString(template, "image_path"))
  const source = `${name} ${image}`
  if (source.includes("greatsword")) return "greatsword"
  if (source.includes("axe")) return "axe"
  if (source.includes("dagger")) return "dagger"
  if (source.includes("spear")) return "spear"
  return "sword"
}

const inferSetKey = (template) => {
  const existing = getString(template, "set_key")
  if (chapter2SetKeys.includes(existing)) return existing

  const source = [
    getString(template, "image_path"),
    getString(template, "name"),
    getString(template, "description"),
  ].join(" ").toLowerCase()

  for (const setKey of chapter2SetKeys) {
    if (source.includes(setKey)) return setKey
  }

  const weaponType = inferWeaponType(template)
  return setKeyByWeaponType[weaponType] || ""
}

const isWeapon = (template) => {
  const slot = getString(template, "equipment_slot")
  const pieceType = getString(template, "set_piece_type")
  const weaponType = getString(template, "weapon_type")
  return slot === "sword" || pieceType === "weapon" || weaponType !== ""
}

const isChapter2Equipment = (template) => {
  const setKey = getString(template, "set_key")
  if (chapter2SetKeys.includes(setKey)) return true
  return hasChapter2Marker(template)
}

const repairOwnedEquipmentStatRanges = (app) => {
  const collection = app.findCollectionByNameOrId("owned_equipments")
  let changed = false
  for (const fieldName of ["rolled_hp", "rolled_attack", "rolled_defense", "rolled_agility"]) {
    const field = collection.fields.getByName(fieldName)
    if (field.min !== null) {
      field.min = null
      changed = true
    }
  }
  if (changed) app.save(collection)
}

const repairChapter2SetFields = (app) => {
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment" && is_active=true`, "", 5000, 0)
  for (const template of templates) {
    if (!isChapter2Equipment(template)) continue

    const slot = getString(template, "equipment_slot")
    const weapon = isWeapon(template)
    const setKey = inferSetKey(template)
    if (!setKey) continue

    const nextPieceType = weapon ? "weapon" : slot
    let changed = false
    if (getString(template, "set_key") !== setKey) {
      template.set("set_key", setKey)
      changed = true
    }
    if (nextPieceType && getString(template, "set_piece_type") !== nextPieceType) {
      template.set("set_piece_type", nextPieceType)
      changed = true
    }
    if (weapon) {
      const weaponType = inferWeaponType(template)
      if (weaponType && getString(template, "weapon_type") !== weaponType) {
        template.set("weapon_type", weaponType)
        changed = true
      }
    }
    if (changed) app.save(template)
  }
}

const syncRareChapter2Prices = (app, priceTable) => {
  const updated = {}
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment" && rarity="rare" && is_active=true`, "", 5000, 0)

  for (const template of templates) {
    if (!isChapter2Equipment(template)) continue

    const slot = getString(template, "equipment_slot")
    const weapon = isWeapon(template)
    const weaponType = inferWeaponType(template)
    const price = weapon ? priceTable.weapon[weaponType] : priceTable.armor[slot]
    if (!price) continue

    template.set("price_coin", price)
    app.save(template)
    updated[template.id] = price
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    const price = updated[templateID]
    if (price === undefined) continue
    shopItem.set("price_coin", price)
    app.save(shopItem)
  }

  const offers = app.findRecordsByFilter("daily_shop_offers", `is_active=true && is_purchased=false`, "", 5000, 0)
  for (const offer of offers) {
    const templateID = String(offer.get("item_template") || "")
    const price = updated[templateID]
    if (price === undefined) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}

const ensureChapter2SetBonusesActive = (app) => {
  for (const setKey of chapter2SetKeys) {
    const bonuses = app.findRecordsByFilter("equipment_set_bonuses", `set_key="${setKey}"`, "", 100, 0)
    for (const bonus of bonuses) {
      if (bonus.get("is_active") !== true) {
        bonus.set("is_active", true)
        app.save(bonus)
      }
    }
  }
}

migrate((app) => {
  repairOwnedEquipmentStatRanges(app)
  repairChapter2SetFields(app)
  syncRareChapter2Prices(app, rareChapter2Prices)
  ensureChapter2SetBonusesActive(app)
}, (app) => {
  syncRareChapter2Prices(app, previousRareChapter2Prices)
})
