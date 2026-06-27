migrate((app) => {
  const addSelectValue = (collectionName, fieldName, value) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const field = collection.fields.getByName(fieldName)
    if (!field.values.includes(value)) {
      field.values.push(value)
      app.save(collection)
    }
  }

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

  const findFirstByFilter = (collectionName, filter) => {
    const records = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
    return records.length > 0 ? records[0] : null
  }

  addSelectValue("item_templates", "equipment_slot", "sword")
  addSelectValue("equipment_slot_balances", "slot_type", "sword")

  upsertByFilter("equipment_slot_balances", `slot_type="sword"`, {
    slot_type: "sword",
    main_stat: "attack",
    sub_stat: "attack",
    description: "Sword slot scales with attack.",
  })

  const normalizeEquipmentStats = () => {
    const statByRarity = {
      common: {
        helmet: { hp: 20 },
        armor: { defense: 3 },
        shoes: { agility: 5 },
        sword: { attack: 3 },
      },
      rare: {
        helmet: { hp: 45 },
        armor: { defense: 7 },
        shoes: { agility: 10 },
        sword: { attack: 7 },
      },
      epic: {
        helmet: { hp: 80 },
        armor: { defense: 14 },
        shoes: { agility: 18 },
        sword: { attack: 14 },
      },
      legendary: {
        helmet: { hp: 130 },
        armor: { defense: 24 },
        shoes: { agility: 30 },
        sword: { attack: 24 },
      },
      mythic: {
        helmet: { hp: 200 },
        armor: { defense: 38 },
        shoes: { agility: 45 },
        sword: { attack: 38 },
      },
    }

    const records = app.findRecordsByFilter("item_templates", `item_type="equipment" && is_active=true`, "", 500, 0)
    for (const record of records) {
      const slot = record.get("equipment_slot")
      const rarity = record.get("rarity")
      const rarityStats = statByRarity[rarity]
      if (!rarityStats) continue

      const slotStats = rarityStats[slot]
      if (!slotStats) continue

      record.set("recover_hp", 0)
      record.set("base_hp", slotStats.hp || 0)
      record.set("base_attack", slotStats.attack || 0)
      record.set("base_defense", slotStats.defense || 0)
      record.set("base_agility", slotStats.agility || 0)
      app.save(record)
    }
  }

  const equipmentTemplates = [
    {
      name: "초급 검",
      item_type: "equipment",
      equipment_slot: "sword",
      rarity: "common",
      recover_hp: 0,
      base_hp: 0,
      base_attack: 3,
      base_defense: 0,
      base_agility: 0,
      max_stack_quantity: 1,
      price_coin: 50,
      description: "기본 공격력을 올려주는 검입니다.",
      is_active: true,
    },
    {
      name: "레어 검",
      item_type: "equipment",
      equipment_slot: "sword",
      rarity: "rare",
      recover_hp: 0,
      base_hp: 0,
      base_attack: 7,
      base_defense: 0,
      base_agility: 0,
      max_stack_quantity: 1,
      price_coin: 150,
      description: "공격력이 크게 오르는 검입니다.",
      is_active: true,
    },
    {
      name: "에픽 검",
      item_type: "equipment",
      equipment_slot: "sword",
      rarity: "epic",
      recover_hp: 0,
      base_hp: 0,
      base_attack: 14,
      base_defense: 0,
      base_agility: 0,
      max_stack_quantity: 1,
      price_coin: 450,
      description: "에픽 등급 검입니다.",
      is_active: true,
    },
    {
      name: "에픽 투구",
      item_type: "equipment",
      equipment_slot: "helmet",
      rarity: "epic",
      recover_hp: 0,
      base_hp: 80,
      base_attack: 0,
      base_defense: 0,
      base_agility: 0,
      max_stack_quantity: 1,
      price_coin: 380,
      description: "에픽 등급 투구입니다.",
      is_active: true,
    },
    {
      name: "에픽 갑옷",
      item_type: "equipment",
      equipment_slot: "armor",
      rarity: "epic",
      recover_hp: 0,
      base_hp: 0,
      base_attack: 0,
      base_defense: 14,
      base_agility: 0,
      max_stack_quantity: 1,
      price_coin: 430,
      description: "에픽 등급 갑옷입니다.",
      is_active: true,
    },
    {
      name: "에픽 신발",
      item_type: "equipment",
      equipment_slot: "shoes",
      rarity: "epic",
      recover_hp: 0,
      base_hp: 0,
      base_attack: 0,
      base_defense: 0,
      base_agility: 18,
      max_stack_quantity: 1,
      price_coin: 360,
      description: "에픽 등급 신발입니다.",
      is_active: true,
    },
  ]

  for (const item of equipmentTemplates) {
    upsertByFilter("item_templates", `name="${item.name}"`, item)
  }
  normalizeEquipmentStats()

  const consumables = [
    {
      name: "중급 회복 물약",
      item_type: "consumable",
      rarity: "rare",
      recover_hp: 120,
      max_stack_quantity: 99,
      price_coin: 75,
      description: "HP를 120 회복합니다.",
      is_active: true,
    },
    {
      name: "고급 회복 물약",
      item_type: "consumable",
      rarity: "epic",
      recover_hp: 250,
      max_stack_quantity: 99,
      price_coin: 160,
      description: "HP를 250 회복합니다.",
      is_active: true,
    },
    {
      name: "5스테이지 보스 입장권",
      item_type: "consumable",
      rarity: "epic",
      recover_hp: 0,
      max_stack_quantity: 99,
      price_coin: 300,
      description: "5스테이지 보스에게 도전할 때 필요한 입장권입니다.",
      is_active: true,
    },
  ]

  for (const item of consumables) {
    upsertByFilter("item_templates", `name="${item.name}"`, {
      base_hp: 0,
      base_attack: 0,
      base_defense: 0,
      base_agility: 0,
      ...item,
    })
  }

  const monsters = [
    {
      name: "숲 늑대",
      monster_type: "normal",
      required_distance_min_m: 1400,
      required_distance_max_m: 2200,
      reward_coin_min: 90,
      reward_coin_max: 130,
      hp: 150,
      attack: 16,
      defense: 3,
      agility: 4,
      is_active: true,
    },
    {
      name: "동굴 골렘",
      monster_type: "normal",
      required_distance_min_m: 2200,
      required_distance_max_m: 3200,
      reward_coin_min: 130,
      reward_coin_max: 180,
      hp: 230,
      attack: 22,
      defense: 8,
      agility: 1,
      is_active: true,
    },
    {
      name: "고대 수문장",
      monster_type: "boss",
      required_distance_min_m: 3500,
      required_distance_max_m: 5000,
      reward_coin_min: 350,
      reward_coin_max: 500,
      hp: 820,
      attack: 38,
      defense: 14,
      agility: 5,
      is_active: true,
    },
  ]

  for (const monster of monsters) {
    upsertByFilter("monsters", `name="${monster.name}"`, monster)
  }

  const stage3 = upsertByFilter("stages", `stage_no=3 && stage_type="normal"`, {
    stage_no: 3,
    title: "숲길 - 3",
    stage_type: "normal",
    monster_count: 1,
    recommended_distance_min_m: 1400,
    recommended_distance_max_m: 2200,
    is_active: true,
  })
  const stage4 = upsertByFilter("stages", `stage_no=4 && stage_type="normal"`, {
    stage_no: 4,
    title: "동굴 입구 - 4",
    stage_type: "normal",
    monster_count: 1,
    recommended_distance_min_m: 2200,
    recommended_distance_max_m: 3200,
    is_active: true,
  })
  const stage5 = upsertByFilter("stages", `stage_no=5 && stage_type="boss"`, {
    stage_no: 5,
    title: "고대 수문장 - 5",
    stage_type: "boss",
    monster_count: 1,
    recommended_distance_min_m: 3500,
    recommended_distance_max_m: 5000,
    is_active: true,
  })

  const wolf = findFirstByFilter("monsters", `name="숲 늑대"`)
  const golem = findFirstByFilter("monsters", `name="동굴 골렘"`)
  const guardian = findFirstByFilter("monsters", `name="고대 수문장"`)

  upsertByFilter("stage_monsters", `stage="${stage3.id}" && spawn_order=1`, {
    stage: stage3.id,
    monster: wolf.id,
    spawn_order: 1,
    is_boss: false,
  })
  upsertByFilter("stage_monsters", `stage="${stage4.id}" && spawn_order=1`, {
    stage: stage4.id,
    monster: golem.id,
    spawn_order: 1,
    is_boss: false,
  })
  upsertByFilter("stage_monsters", `stage="${stage5.id}" && spawn_order=1`, {
    stage: stage5.id,
    monster: guardian.id,
    spawn_order: 1,
    is_boss: true,
  })

  const shop = findFirstByFilter("shops", `shop_type="normal" && is_active=true`) ||
    upsertByFilter("shops", `name="기본 상점"`, {
      name: "기본 상점",
      shop_type: "normal",
      is_active: true,
    })

  for (const item of consumables) {
    const template = findFirstByFilter("item_templates", `name="${item.name}"`)
    upsertByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, {
      shop: shop.id,
      item_template: template.id,
      price_coin: item.price_coin,
      is_active: true,
    })
  }
}, (app) => {
  // Keep live game content on rollback.
})
