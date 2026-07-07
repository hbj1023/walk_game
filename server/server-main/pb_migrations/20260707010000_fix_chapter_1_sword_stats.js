migrate((app) => {
  const swordConfigs = [
    {
      rarity: "common",
      names: ["부서진 검", "낡은검", "초급 검", "초급검"],
      name: "부서진 검",
      attack: 5,
      defense: 0,
      price: 80,
      image: "assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png",
      description: "금이 간 초급 무기입니다. 공격력 +5.",
    },
    {
      rarity: "rare",
      names: ["일반검", "레어 검", "레어검"],
      name: "일반검",
      attack: 12,
      defense: 2,
      price: 220,
      image: "assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png",
      description: "튜토리얼 후반을 넘기기 위한 기본 검입니다. 공격력 +12, 방어 +2.",
    },
    {
      rarity: "epic",
      names: ["에픽 검", "에픽검"],
      name: "에픽 검",
      attack: 24,
      defense: 4,
      price: 700,
      image: "assets/images/equipment/chapter1/epic_green_brass_sword.png",
      description: "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 검입니다. 공격력 +24, 방어 +4.",
    },
  ]

  const compact = (value) => String(value || "").replace(/\s/g, "")
  const templatePrices = {}

  for (const config of swordConfigs) {
    const templates = app.findRecordsByFilter(
      "item_templates",
      `item_type="equipment" && equipment_slot="sword" && rarity="${config.rarity}" && is_active=true`,
      "",
      1000,
      0,
    )

    for (const template of templates) {
      const setKey = String(template.get("set_key") || "")
      const setPieceType = String(template.get("set_piece_type") || "")
      const weaponType = String(template.get("weapon_type") || "")
      const nameKey = compact(template.get("name"))
      const matchesName = config.names.map(compact).includes(nameKey)
      const looksLikeChapter1Sword = setKey === "" && (setPieceType === "" || setPieceType === "weapon") && (weaponType === "" || weaponType === "sword")

      if (!matchesName && !looksLikeChapter1Sword) continue
      if (setKey !== "") continue

      template.set("name", config.name)
      template.set("weapon_type", "sword")
      template.set("set_key", "")
      template.set("set_piece_type", "weapon")
      template.set("base_hp", 0)
      template.set("base_attack", config.attack)
      template.set("base_defense", config.defense)
      template.set("base_agility", 0)
      template.set("recover_hp", 0)
      template.set("max_stack_quantity", 1)
      template.set("price_coin", config.price)
      template.set("image_path", config.image)
      template.set("description", config.description)
      template.set("is_active", true)
      app.save(template)
      templatePrices[template.id] = config.price
    }
  }

  const shopItems = app.findRecordsByFilter("shop_items", "", "", 1000, 0)
  for (const shopItem of shopItems) {
    const templateID = String(shopItem.get("item_template") || "")
    const price = templatePrices[templateID]
    if (price === undefined) continue
    shopItem.set("price_coin", price)
    app.save(shopItem)
  }

  const offers = app.findRecordsByFilter(
    "daily_shop_offers",
    `is_active=true && is_purchased=false`,
    "",
    1000,
    0,
  )
  for (const offer of offers) {
    const templateID = String(offer.get("item_template") || "")
    const price = templatePrices[templateID]
    if (price === undefined) continue
    offer.set("original_price_coin", price)
    offer.set("price_coin", Math.floor(price * 0.9))
    app.save(offer)
  }
}, (app) => {
  // Keep live equipment balance values on rollback.
})