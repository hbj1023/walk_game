const canonicalChapterEpics = [
  { name: "\ubaa8\ud5d8\uac00\uc758 \uac80", aliases: ["\uc5d0\ud53d \uac80"], setKey: "", piece: "weapon", slot: "sword", weaponType: "sword", image: "assets/images/equipment/chapter1/epic_green_brass_sword.png", price: 700, hp: 0, attack: 24, defense: 4, agility: 0, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \uac80\uc785\ub2c8\ub2e4. \uacf5\uaca9\ub825 +24, \ubc29\uc5b4\ub825 +4." },
  { name: "\ubaa8\ud5d8\uac00\uc758 \ud22c\uad6c", aliases: ["\uc5d0\ud53d \ud22c\uad6c"], setKey: "", piece: "helmet", slot: "helmet", weaponType: "", image: "assets/images/equipment/chapter1/epic_green_brass_helmet.png", price: 380, hp: 80, attack: 0, defense: 0, agility: 0, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \ud22c\uad6c\uc785\ub2c8\ub2e4. HP +80." },
  { name: "\ubaa8\ud5d8\uac00\uc758 \uac11\uc637", aliases: ["\uc5d0\ud53d \uac11\uc637"], setKey: "", piece: "armor", slot: "armor", weaponType: "", image: "assets/images/equipment/chapter1/epic_green_brass_armor.png", price: 430, hp: 0, attack: 0, defense: 14, agility: 0, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \uac11\uc637\uc785\ub2c8\ub2e4. \ubc29\uc5b4\ub825 +14." },
  { name: "\ubaa8\ud5d8\uac00\uc758 \uc2e0\ubc1c", aliases: ["\uc5d0\ud53d \uc2e0\ubc1c"], setKey: "", piece: "shoes", slot: "shoes", weaponType: "", image: "assets/images/equipment/chapter1/epic_green_brass_boots.png", price: 360, hp: 0, attack: 0, defense: 0, agility: 18, description: "\uc232\uae38 \ubcf4\uc2a4\ub97c \uc4f0\ub7ec\ub728\ub9b0 \ubaa8\ud5d8\uac00\uc758 \uc2e0\ubc1c\uc785\ub2c8\ub2e4. \ubbfc\ucca9 +18." },
  { name: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \ub2e8\uac80", aliases: [], setKey: "poison_assassin", piece: "weapon", slot: "sword", weaponType: "dagger", image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_dagger.png", price: 950, hp: 0, attack: 38, defense: 0, agility: 45, description: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uc138\ud2b8\uc758 \uc5d0\ud53d \ub2e8\uac80\uc785\ub2c8\ub2e4. \uacf5\uaca9\ub825 +38, \ubbfc\ucca9 +45." },
  { name: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \ubcf5\uba74", aliases: [], setKey: "poison_assassin", piece: "helmet", slot: "helmet", weaponType: "", image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_helmet.png", price: 520, hp: 140, attack: 4, defense: 7, agility: 18, description: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uc138\ud2b8\uc758 \uc5d0\ud53d \ubcf5\uba74\uc785\ub2c8\ub2e4. HP +140, \uacf5\uaca9\ub825 +4, \ubc29\uc5b4\ub825 +7, \ubbfc\ucca9 +18." },
  { name: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uac11\uc637", aliases: [], setKey: "poison_assassin", piece: "armor", slot: "armor", weaponType: "", image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_armor.png", price: 680, hp: 210, attack: 6, defense: 24, agility: 14, description: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uc138\ud2b8\uc758 \uc5d0\ud53d \uac11\uc637\uc785\ub2c8\ub2e4. HP +210, \uacf5\uaca9\ub825 +6, \ubc29\uc5b4\ub825 +24, \ubbfc\ucca9 +14." },
  { name: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uc7a5\ud654", aliases: [], setKey: "poison_assassin", piece: "shoes", slot: "shoes", weaponType: "", image: "assets/images/equipment/chapter2/ch2_epic_poison_assassin_boots.png", price: 520, hp: 110, attack: 3, defense: 5, agility: 28, description: "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uc138\ud2b8\uc758 \uc5d0\ud53d \uc7a5\ud654\uc785\ub2c8\ub2e4. HP +110, \uacf5\uaca9\ub825 +3, \ubc29\uc5b4\ub825 +5, \ubbfc\ucca9 +28." },
]

const findCanonicalTemplate = (app, definition) => {
  for (const name of [definition.name, ...definition.aliases]) {
    const records = app.findRecordsByFilter("item_templates", `name="${name}" && rarity="epic"`, "", 10, 0)
    if (records.length > 0) return records[0]
  }
  return new Record(app.findCollectionByNameOrId("item_templates"))
}

const saveCanonicalTemplate = (app, definition) => {
  const template = findCanonicalTemplate(app, definition)
  template.set("name", definition.name)
  template.set("item_type", "equipment")
  template.set("rarity", "epic")
  template.set("set_key", definition.setKey)
  template.set("set_piece_type", definition.piece)
  template.set("equipment_slot", definition.slot)
  template.set("weapon_type", definition.weaponType)
  template.set("image_path", definition.image)
  template.set("price_coin", definition.price)
  template.set("base_hp", definition.hp)
  template.set("base_attack", definition.attack)
  template.set("base_defense", definition.defense)
  template.set("base_agility", definition.agility)
  template.set("recover_hp", 0)
  template.set("max_stack_quantity", 1)
  template.set("description", definition.description)
  template.set("is_active", true)
  app.save(template)
  return template
}

const ensureNormalShopItem = (app, shop, template, price) => {
  const records = app.findRecordsByFilter(
    "shop_items",
    `shop="${shop.id}" && item_template="${template.id}"`,
    "",
    10,
    0,
  )
  const item = records.length > 0
    ? records[0]
    : new Record(app.findCollectionByNameOrId("shop_items"))
  item.set("shop", shop.id)
  item.set("item_template", template.id)
  item.set("price_coin", price)
  item.set("stock_limit", 0)
  item.set("purchase_limit_per_user", 0)
  item.set("is_active", true)
  app.save(item)
}

migrate((app) => {
  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)
  if (shops.length === 0) throw new Error("active normal shop not found")

  for (const definition of canonicalChapterEpics) {
    const template = saveCanonicalTemplate(app, definition)
    for (const shop of shops) ensureNormalShopItem(app, shop, template, definition.price)
  }
}, (app) => {
  // Keep canonical chapter 1 and 2 epic equipment available on rollback.
})
