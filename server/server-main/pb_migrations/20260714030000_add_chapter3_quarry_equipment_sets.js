const quarrySets = [
  {
    key: "quarry_swordsman",
    name: "채석단 검사 세트",
    role: "검사",
    weaponType: "sword",
    weaponName: "검",
    armorAssetKey: "vanguard",
    commonWeapon: { hp: 0, attack: 38, defense: 6, agility: 4, price: 420 },
    rareWeapon: { hp: 0, attack: 50, defense: 10, agility: 6, price: 680 },
    commonArmor: [
      { piece: "helmet", hp: 100, attack: 3, defense: 10, agility: 3, price: 180 },
      { piece: "armor", hp: 160, attack: 3, defense: 18, agility: 2, price: 250 },
      { piece: "shoes", hp: 70, attack: 0, defense: 7, agility: 8, price: 180 },
    ],
    effects: [
      { count: 3, type: "attack_percent", value: 8, description: "3세트: 공격력 +8%" },
      { count: 4, type: "defense_penetration_percent", value: 15, description: "4세트: 적 방어력 15% 무시" },
    ],
  },
  {
    key: "quarry_berserker",
    name: "채석단 광전사 세트",
    role: "광전사",
    weaponType: "axe",
    weaponName: "도끼",
    armorAssetKey: "berserker",
    commonWeapon: { hp: 0, attack: 48, defense: 0, agility: -6, price: 460 },
    rareWeapon: { hp: 0, attack: 62, defense: 0, agility: -8, price: 740 },
    commonArmor: [
      { piece: "helmet", hp: 100, attack: 6, defense: 7, agility: 0, price: 180 },
      { piece: "armor", hp: 150, attack: 8, defense: 14, agility: -2, price: 250 },
      { piece: "shoes", hp: 70, attack: 4, defense: 5, agility: 5, price: 180 },
    ],
    effects: [
      { count: 3, type: "attack_percent", value: 12, description: "3세트: 공격력 +12%" },
      { count: 4, type: "boss_damage_percent", value: 15, description: "4세트: 보스 피해 +15%" },
    ],
  },
  {
    key: "quarry_spearmaster",
    name: "채석단 창술사 세트",
    role: "창술사",
    weaponType: "spear",
    weaponName: "창",
    armorAssetKey: "sentinel",
    commonWeapon: { hp: 0, attack: 34, defense: 12, agility: 6, price: 440 },
    rareWeapon: { hp: 0, attack: 46, defense: 18, agility: 8, price: 700 },
    commonArmor: [
      { piece: "helmet", hp: 110, attack: 0, defense: 12, agility: 4, price: 180 },
      { piece: "armor", hp: 180, attack: 0, defense: 22, agility: 2, price: 250 },
      { piece: "shoes", hp: 80, attack: 0, defense: 8, agility: 10, price: 180 },
    ],
    effects: [
      { count: 3, type: "defense_percent", value: 12, description: "3세트: 방어력 +12%" },
      { count: 4, type: "monster_gauge_percent", value: -10, description: "4세트: 몬스터 공격 게이지 -10%" },
    ],
  },
  {
    key: "quarry_rogue",
    name: "채석단 도적 세트",
    role: "도적",
    weaponType: "dagger",
    weaponName: "단검",
    armorAssetKey: "shadow",
    commonWeapon: { hp: 0, attack: 30, defense: 0, agility: 24, price: 400 },
    rareWeapon: { hp: 0, attack: 40, defense: 0, agility: 34, price: 650 },
    commonArmor: [
      { piece: "helmet", hp: 80, attack: 3, defense: 5, agility: 12, price: 180 },
      { piece: "armor", hp: 130, attack: 4, defense: 10, agility: 15, price: 250 },
      { piece: "shoes", hp: 60, attack: 0, defense: 4, agility: 18, price: 180 },
    ],
    effects: [
      { count: 3, type: "agility_percent", value: 12, description: "3세트: 민첩 +12%" },
      { count: 4, type: "attack_distance_percent", value: -10, description: "4세트: 공격 필요 거리 -10%" },
    ],
  },
  {
    key: "quarry_knight",
    name: "채석단 기사 세트",
    role: "기사",
    weaponType: "greatsword",
    weaponName: "대검",
    armorAssetKey: "colossus",
    commonWeapon: { hp: 0, attack: 56, defense: 0, agility: -10, price: 500 },
    rareWeapon: { hp: 0, attack: 72, defense: 0, agility: -14, price: 800 },
    commonArmor: [
      { piece: "helmet", hp: 130, attack: 2, defense: 14, agility: -2, price: 180 },
      { piece: "armor", hp: 210, attack: 2, defense: 28, agility: -4, price: 250 },
      { piece: "shoes", hp: 90, attack: 0, defense: 10, agility: 3, price: 180 },
    ],
    effects: [
      { count: 3, type: "defense_percent", value: 15, description: "3세트: 방어력 +15%" },
      { count: 4, type: "hp_percent", value: 10, description: "4세트: 최대 HP +10%" },
    ],
  },
]

const textValue = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "").trim()
  } catch (_) {
    return ""
  }
}

const findRecord = (records, predicate) => {
  for (const record of records) {
    if (predicate(record)) return record
  }
  return null
}

const scaledArmorStats = (stats, rarity) => {
  if (rarity === "common") return stats
  return {
    piece: stats.piece,
    hp: Math.round(stats.hp * 1.4),
    attack: Math.round(stats.attack * 1.35),
    defense: Math.round(stats.defense * 1.4),
    agility: Math.round(stats.agility * 1.35),
    price: stats.piece === "armor" ? 420 : 300,
  }
}

const itemDescription = (setName, stats, effects) => {
  const statText = [
    stats.hp ? `최대 HP ${stats.hp > 0 ? "+" : ""}${stats.hp}` : "",
    stats.attack ? `공격력 ${stats.attack > 0 ? "+" : ""}${stats.attack}` : "",
    stats.defense ? `방어력 ${stats.defense > 0 ? "+" : ""}${stats.defense}` : "",
    stats.agility ? `민첩 ${stats.agility > 0 ? "+" : ""}${stats.agility}` : "",
  ].filter(Boolean).join(", ")
  return `${setName}. ${statText}. ${effects.map((effect) => effect.description).join(" / ")}`
}

migrate((app) => {
  const templateCollection = app.findCollectionByNameOrId("item_templates")
  const bonusCollection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const shopItemCollection = app.findCollectionByNameOrId("shop_items")
  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 1, 0)
  const shop = shops.length > 0 ? shops[0] : null
  const templates = app.findRecordsByFilter("item_templates", "", "", 5000, 0)
  const shopItems = app.findRecordsByFilter("shop_items", "", "", 5000, 0)
  const bonuses = app.findRecordsByFilter("equipment_set_bonuses", "", "", 1000, 0)

  for (const template of templates) {
    if (textValue(template, "set_key") !== "crusher") continue
    template.set("is_active", false)
    app.save(template)
  }
  for (const bonus of bonuses) {
    if (textValue(bonus, "set_key") !== "crusher") continue
    bonus.set("is_active", false)
    app.save(bonus)
  }

  for (const set of quarrySets) {
    for (const rarity of ["common", "rare"]) {
      const weaponStats = rarity === "common" ? set.commonWeapon : set.rareWeapon
      const itemDefs = [
        {
          piece: "weapon",
          slot: "sword",
          weaponType: set.weaponType,
          name: `${rarity === "rare" ? "강화된 " : ""}채석단 ${set.role} ${set.weaponName}`,
          image: `assets/images/equipment/chapter3/ch3_weapon_${rarity === "rare" ? "rare_" : ""}${set.weaponType}.png`,
          stats: weaponStats,
        },
        ...set.commonArmor.map((baseStats) => {
          const stats = scaledArmorStats(baseStats, rarity)
          const pieceName = stats.piece === "helmet" ? "투구" : stats.piece === "armor" ? "갑옷" : "장화"
          const assetPiece = stats.piece === "shoes" ? "boots" : stats.piece
          return {
            piece: stats.piece,
            slot: stats.piece,
            weaponType: "",
            name: `${rarity === "rare" ? "강화된 " : ""}채석단 ${set.role} ${pieceName}`,
            image: `assets/images/equipment/chapter2/ch2_armor_rare_${set.armorAssetKey}_${assetPiece}.png`,
            stats,
          }
        }),
      ]

      for (const item of itemDefs) {
        let template = findRecord(
          templates,
          (candidate) => textValue(candidate, "set_key") === set.key &&
            textValue(candidate, "set_piece_type") === item.piece &&
            textValue(candidate, "rarity") === rarity,
        )
        if (!template) {
          template = new Record(templateCollection)
          templates.push(template)
        }
        template.set("name", item.name)
        template.set("item_type", "equipment")
        template.set("rarity", rarity)
        template.set("equipment_slot", item.slot)
        template.set("weapon_type", item.weaponType)
        template.set("set_key", set.key)
        template.set("set_piece_type", item.piece)
        template.set("base_hp", item.stats.hp)
        template.set("base_attack", item.stats.attack)
        template.set("base_defense", item.stats.defense)
        template.set("base_agility", item.stats.agility)
        template.set("price_coin", item.stats.price)
        template.set("image_path", item.image)
        template.set("description", itemDescription(set.name, item.stats, set.effects))
        template.set("recover_hp", 0)
        template.set("max_stack", 1)
        template.set("is_active", true)
        app.save(template)

        if (shop) {
          let shopItem = findRecord(
            shopItems,
            (candidate) => textValue(candidate, "shop") === shop.id &&
              textValue(candidate, "item_template") === template.id,
          )
          if (!shopItem) {
            shopItem = new Record(shopItemCollection)
            shopItems.push(shopItem)
          }
          shopItem.set("shop", shop.id)
          shopItem.set("item_template", template.id)
          shopItem.set("price_coin", item.stats.price)
          shopItem.set("stock_limit", 0)
          shopItem.set("is_active", true)
          app.save(shopItem)
        }
      }
    }

    for (const effect of set.effects) {
      let bonus = findRecord(
        bonuses,
        (candidate) => textValue(candidate, "set_key") === set.key &&
          Number(candidate.get("required_count") || 0) === effect.count &&
          textValue(candidate, "bonus_type") === effect.type,
      )
      if (!bonus) {
        bonus = new Record(bonusCollection)
        bonuses.push(bonus)
      }
      bonus.set("set_key", set.key)
      bonus.set("set_name", set.name)
      bonus.set("required_count", effect.count)
      bonus.set("bonus_type", effect.type)
      bonus.set("bonus_value", effect.value)
      bonus.set("description", effect.description)
      bonus.set("is_active", true)
      app.save(bonus)
    }
  }

  const retiredIDs = {}
  for (const template of templates) {
    if (textValue(template, "set_key") !== "crusher") continue
    retiredIDs[template.id] = true
  }
  for (const shopItem of shopItems) {
    if (!retiredIDs[textValue(shopItem, "item_template")]) continue
    shopItem.set("is_active", false)
    app.save(shopItem)
  }
}, (app) => {
  // Live chapter 3 equipment records are preserved on rollback.
})
