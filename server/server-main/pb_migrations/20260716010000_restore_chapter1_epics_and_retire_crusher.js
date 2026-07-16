const chapter1Epics = [
  { key: "chapter1.epic.adventurer.weapon", name: "\ubaa8\ud5d8\uac00\uc758 \uac80", piece: "weapon", slot: "sword", weapon: "sword", image: "assets/images/equipment/chapter1/epic_green_brass_sword.png", price: 700, hp: 0, attack: 24, defense: 4, agility: 0, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \uac80\uc785\ub2c8\ub2e4. \uacf5\uaca9\ub825 +24, \ubc29\uc5b4\ub825 +4." },
  { key: "chapter1.epic.adventurer.helmet", name: "\ubaa8\ud5d8\uac00\uc758 \ud22c\uad6c", piece: "helmet", slot: "helmet", weapon: "", image: "assets/images/equipment/chapter1/epic_green_brass_helmet.png", price: 380, hp: 80, attack: 0, defense: 0, agility: 0, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \ud22c\uad6c\uc785\ub2c8\ub2e4. HP +80." },
  { key: "chapter1.epic.adventurer.armor", name: "\ubaa8\ud5d8\uac00\uc758 \uac11\uc637", piece: "armor", slot: "armor", weapon: "", image: "assets/images/equipment/chapter1/epic_green_brass_armor.png", price: 430, hp: 0, attack: 0, defense: 14, agility: 0, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \uac11\uc637\uc785\ub2c8\ub2e4. \ubc29\uc5b4\ub825 +14." },
  { key: "chapter1.epic.adventurer.shoes", name: "\ubaa8\ud5d8\uac00\uc758 \uc2e0\ubc1c", piece: "shoes", slot: "shoes", weapon: "", image: "assets/images/equipment/chapter1/epic_green_brass_boots.png", price: 360, hp: 0, attack: 0, defense: 0, agility: 18, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \uc2e0\ubc1c\uc785\ub2c8\ub2e4. \ubbfc\ucca9 +18." },
]

const textValue = (record, field) => {
  try {
    return String(record.get(field) || "").trim()
  } catch (error) {
    return ""
  }
}

const applyChapter1Definition = (record, definition) => {
  record.set("catalog_key", definition.key)
  record.set("name", definition.name)
  record.set("item_type", "equipment")
  record.set("rarity", "epic")
  record.set("set_key", "")
  record.set("set_piece_type", definition.piece)
  record.set("equipment_slot", definition.slot)
  record.set("weapon_type", definition.weapon)
  record.set("image_path", definition.image)
  record.set("price_coin", definition.price)
  record.set("base_hp", definition.hp)
  record.set("base_attack", definition.attack)
  record.set("base_defense", definition.defense)
  record.set("base_agility", definition.agility)
  record.set("recover_hp", 0)
  record.set("max_stack_quantity", 1)
  record.set("description", definition.description)
  record.set("is_active", true)
}

migrate((app) => {
  const templates = app.findRecordsByFilter("item_templates", 'item_type="equipment"', "", 5000, 0)
  const shops = app.findRecordsByFilter("shops", 'shop_type="normal" && is_active=true', "", 100, 0)
  if (shops.length === 0) throw new Error("active normal shop not found")

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  const shopItemsCollection = app.findCollectionByNameOrId("shop_items")
  const canonicalIDs = {}

  for (const definition of chapter1Epics) {
    let canonical = templates.find((record) => textValue(record, "catalog_key") === definition.key)
    if (!canonical) canonical = templates.find((record) => textValue(record, "image_path") === definition.image)
    if (!canonical) canonical = templates.find((record) => textValue(record, "name") === definition.name && textValue(record, "rarity") === "epic")
    if (!canonical) {
      canonical = new Record(app.findCollectionByNameOrId("item_templates"))
      templates.push(canonical)
    }

    applyChapter1Definition(canonical, definition)
    app.save(canonical)
    canonicalIDs[canonical.id] = true

    for (const shop of shops) {
      let link = shopItems.find((record) => textValue(record, "shop") === shop.id && textValue(record, "item_template") === canonical.id)
      if (!link) {
        link = new Record(shopItemsCollection)
        shopItems.push(link)
      }
      link.set("shop", shop.id)
      link.set("item_template", canonical.id)
      link.set("price_coin", definition.price)
      link.set("stock_limit", 0)
      link.set("purchase_limit_per_user", 0)
      link.set("is_active", true)
      app.save(link)
    }
  }

  const retiredIDs = {}
  for (const template of templates) {
    const name = textValue(template, "name")
    const image = textValue(template, "image_path")
    const setKey = textValue(template, "set_key")
    const duplicateChapter1 = chapter1Epics.some((definition) =>
      (name === definition.name || image === definition.image) && !canonicalIDs[template.id]
    )
    const crusher = setKey === "crusher" || name.startsWith("\ud30c\uc1c4\uc790 ")
    if (!duplicateChapter1 && !crusher) continue

    template.set("is_active", false)
    app.save(template)
    retiredIDs[template.id] = true
  }

  for (const link of shopItems) {
    if (!retiredIDs[textValue(link, "item_template")]) continue
    link.set("is_active", false)
    app.save(link)
  }

  for (const bonus of app.findRecordsByFilter("equipment_set_bonuses", "", "", 1000, 0)) {
    if (textValue(bonus, "set_key") !== "crusher") continue
    bonus.set("is_active", false)
    app.save(bonus)
  }

  console.log(`[catalog-repair] restored ${Object.keys(canonicalIDs).length} chapter 1 epics and retired ${Object.keys(retiredIDs).length} duplicate/crusher templates`)
}, (app) => {
  // Preserve canonical equipment and reference-safe retirement on rollback.
})
