migrate((app) => {
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

  const addStat = (stats, stat, value) => {
    if (!value) return
    if (stat === "hp") stats.base_hp = (stats.base_hp || 0) + value
    if (stat === "attack") stats.base_attack = (stats.base_attack || 0) + value
    if (stat === "defense") stats.base_defense = (stats.base_defense || 0) + value
    if (stat === "agility") stats.base_agility = (stats.base_agility || 0) + value
  }

  const rarities = {
    common: {
      label: "Common",
      aux: 3,
      prices: { helmet: 520, armor: 680, shoes: 520, weapon: 760 },
      armor: {
        helmet: { hp: 80 },
        armor: { hp: 120, defense: 10 },
        shoes: { hp: 45, agility: 10 },
      },
      weapons: {
        sword: { attack: 18, defense: 3 },
        axe: { attack: 24, agility: -4 },
        spear: { attack: 16, defense: 8 },
        dagger: { attack: 13, agility: 16 },
        greatsword: { attack: 30, agility: -9 },
      },
    },
    rare: {
      label: "Rare",
      aux: 5,
      prices: { helmet: 1450, armor: 1850, shoes: 1450, weapon: 2100 },
      armor: {
        helmet: { hp: 125 },
        armor: { hp: 185, defense: 16 },
        shoes: { hp: 70, agility: 16 },
      },
      weapons: {
        sword: { attack: 28, defense: 5 },
        axe: { attack: 37, agility: -6 },
        spear: { attack: 25, defense: 12 },
        dagger: { attack: 20, agility: 25 },
        greatsword: { attack: 47, agility: -14 },
      },
    },
    epic: {
      label: "Epic",
      aux: 7,
      prices: { helmet: 3600, armor: 4400, shoes: 3600, weapon: 5200 },
      armor: {
        helmet: { hp: 165 },
        armor: { hp: 245, defense: 21 },
        shoes: { hp: 95, agility: 21 },
      },
      weapons: {
        sword: { attack: 37, defense: 7 },
        axe: { attack: 49, agility: -8 },
        spear: { attack: 33, defense: 16 },
        dagger: { attack: 27, agility: 33 },
        greatsword: { attack: 62, agility: -18 },
      },
    },
  }

  const sets = [
    {
      key: "vanguard",
      name: "Vanguard",
      weaponType: "sword",
      weaponName: "Sword",
      aux: { helmet: "defense", armor: "defense", shoes: "defense" },
    },
    {
      key: "berserker",
      name: "Berserker",
      weaponType: "axe",
      weaponName: "Axe",
      aux: { helmet: "attack", armor: "attack", shoes: "attack" },
    },
    {
      key: "sentinel",
      name: "Sentinel",
      weaponType: "spear",
      weaponName: "Spear",
      aux: { helmet: "defense", armor: "defense", shoes: "agility" },
    },
    {
      key: "shadow",
      name: "Shadow",
      weaponType: "dagger",
      weaponName: "Dagger",
      aux: { helmet: "agility", armor: "agility", shoes: "agility" },
    },
    {
      key: "colossus",
      name: "Colossus",
      weaponType: "greatsword",
      weaponName: "Greatsword",
      aux: { helmet: "attack", armor: "defense", shoes: "attack" },
    },
  ]

  const slotNames = {
    helmet: "Helm",
    armor: "Armor",
    shoes: "Boots",
  }

  const createdTemplates = []
  for (const [rarity, balance] of Object.entries(rarities)) {
    for (const set of sets) {
      const weaponStats = {
        base_hp: 0,
        base_attack: 0,
        base_defense: 0,
        base_agility: 0,
        ...balance.weapons[set.weaponType],
      }
      createdTemplates.push(upsertByFilter("item_templates", `name="${balance.label} ${set.name} ${set.weaponName}"`, {
        name: `${balance.label} ${set.name} ${set.weaponName}`,
        item_type: "equipment",
        equipment_slot: "sword",
        weapon_type: set.weaponType,
        set_key: set.key,
        set_piece_type: "weapon",
        image_path: "",
        rarity,
        recover_hp: 0,
        max_stack_quantity: 1,
        price_coin: balance.prices.weapon,
        description: `Chapter 2 ${set.name} ${set.weaponName}.`,
        is_active: true,
        ...weaponStats,
      }))

      for (const slot of ["helmet", "armor", "shoes"]) {
        const stats = {
          base_hp: balance.armor[slot].hp || 0,
          base_attack: balance.armor[slot].attack || 0,
          base_defense: balance.armor[slot].defense || 0,
          base_agility: balance.armor[slot].agility || 0,
        }
        addStat(stats, set.aux[slot], balance.aux)
        createdTemplates.push(upsertByFilter("item_templates", `name="${balance.label} ${set.name} ${slotNames[slot]}"`, {
          name: `${balance.label} ${set.name} ${slotNames[slot]}`,
          item_type: "equipment",
          equipment_slot: slot,
          weapon_type: "",
          set_key: set.key,
          set_piece_type: slot,
          image_path: "",
          rarity,
          recover_hp: 0,
          max_stack_quantity: 1,
          price_coin: balance.prices[slot],
          description: `Chapter 2 ${set.name} ${slotNames[slot]}.`,
          is_active: true,
          ...stats,
        }))
      }
    }
  }

  const setBonuses = [
    { set_key: "vanguard", set_name: "Vanguard", required_count: 3, bonus_type: "hp_percent", bonus_value: 5, description: "3 armor pieces: HP +5%" },
    { set_key: "vanguard", set_name: "Vanguard", required_count: 4, bonus_type: "damage_taken_percent", bonus_value: -3, description: "Full set: damage taken -3%" },
    { set_key: "berserker", set_name: "Berserker", required_count: 3, bonus_type: "attack_percent", bonus_value: 5, description: "3 armor pieces: attack +5%" },
    { set_key: "berserker", set_name: "Berserker", required_count: 4, bonus_type: "attack_percent", bonus_value: 10, description: "Full set: attack +10%" },
    { set_key: "sentinel", set_name: "Sentinel", required_count: 3, bonus_type: "defense_percent", bonus_value: 8, description: "3 armor pieces: defense +8%" },
    { set_key: "sentinel", set_name: "Sentinel", required_count: 4, bonus_type: "monster_gauge_percent", bonus_value: -8, description: "Full set: monster attack gauge -8%" },
    { set_key: "shadow", set_name: "Shadow", required_count: 3, bonus_type: "agility_percent", bonus_value: 8, description: "3 armor pieces: agility +8%" },
    { set_key: "shadow", set_name: "Shadow", required_count: 4, bonus_type: "attack_distance_percent", bonus_value: -8, description: "Full set: attack distance -8%" },
    { set_key: "colossus", set_name: "Colossus", required_count: 3, bonus_type: "attack_percent", bonus_value: 8, description: "3 armor pieces: attack +8%" },
    { set_key: "colossus", set_name: "Colossus", required_count: 4, bonus_type: "boss_damage_percent", bonus_value: 10, description: "Full set: boss damage +10%" },
  ]

  for (const bonus of setBonuses) {
    upsertByFilter(
      "equipment_set_bonuses",
      `set_key="${bonus.set_key}" && required_count=${bonus.required_count} && bonus_type="${bonus.bonus_type}"`,
      {
        ...bonus,
        is_active: true,
      },
    )
  }

  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 1, 0)
  if (shops.length > 0) {
    const shop = shops[0]
    for (const template of createdTemplates) {
      const rarity = template.get("rarity")
      upsertByFilter("shop_items", `shop="${shop.id}" && item_template="${template.id}"`, {
        shop: shop.id,
        item_template: template.id,
        price_coin: Number(template.get("price_coin") || 0),
        stock_limit: 0,
        purchase_limit_per_user: 0,
        is_active: rarity !== "epic",
      })
    }
  }

  const upsertStageMonster = (stage, target) => {
    const existingLinks = app.findRecordsByFilter("stage_monsters", `stage="${stage.id}" && spawn_order=1`, "", 1, 0)
    let monster = null
    if (existingLinks.length > 0) {
      const monsterID = existingLinks[0].get("monster")
      if (monsterID) {
        try {
          monster = app.findRecordById("monsters", monsterID)
        } catch (_) {
          monster = null
        }
      }
    }
    if (!monster) {
      monster = upsertByFilter("monsters", `name="${target.monster.name}" && monster_type="${target.monster.monster_type}"`, target.monster)
    }
    for (const [key, value] of Object.entries(target.monster)) {
      monster.set(key, value)
    }
    app.save(monster)

    upsertByFilter("stage_monsters", `stage="${stage.id}" && spawn_order=1`, {
      stage: stage.id,
      monster: monster.id,
      spawn_order: 1,
      is_boss: target.stage.stage_type === "boss",
    })
  }

  const stageTargets = [
    {
      stage: { stage_no: 6, title: "그늘버섯 숲 - 2-1", stage_type: "normal", monster_count: 1, recommended_distance_min_m: 3200, recommended_distance_max_m: 4300, is_active: true },
      monster: { name: "포자 버섯병사", monster_type: "normal", required_distance_min_m: 3200, required_distance_max_m: 4300, reward_coin_min: 180, reward_coin_max: 250, hp: 760, attack: 42, defense: 10, agility: 8, is_active: true },
    },
    {
      stage: { stage_no: 7, title: "그늘버섯 숲 - 2-2", stage_type: "normal", monster_count: 1, recommended_distance_min_m: 3800, recommended_distance_max_m: 5000, is_active: true },
      monster: { name: "가시 버섯병사", monster_type: "normal", required_distance_min_m: 3800, required_distance_max_m: 5000, reward_coin_min: 240, reward_coin_max: 330, hp: 900, attack: 49, defense: 14, agility: 7, is_active: true },
    },
    {
      stage: { stage_no: 8, title: "그늘버섯 숲 - 2-3", stage_type: "normal", monster_count: 1, recommended_distance_min_m: 4400, recommended_distance_max_m: 5800, is_active: true },
      monster: { name: "독버섯 주술사", monster_type: "normal", required_distance_min_m: 4400, required_distance_max_m: 5800, reward_coin_min: 320, reward_coin_max: 430, hp: 1080, attack: 58, defense: 16, agility: 11, is_active: true },
    },
    {
      stage: { stage_no: 9, title: "그늘버섯 숲 - 2-4", stage_type: "normal", monster_count: 1, recommended_distance_min_m: 5200, recommended_distance_max_m: 6800, is_active: true },
      monster: { name: "서리 버섯병사", monster_type: "normal", required_distance_min_m: 5200, required_distance_max_m: 6800, reward_coin_min: 410, reward_coin_max: 540, hp: 1280, attack: 68, defense: 19, agility: 9, is_active: true },
    },
    {
      stage: { stage_no: 10, title: "그늘버섯 숲 - 2-5", stage_type: "boss", monster_count: 1, recommended_distance_min_m: 7000, recommended_distance_max_m: 9000, is_active: true },
      monster: { name: "장로 버섯군주", monster_type: "boss", required_distance_min_m: 7000, required_distance_max_m: 9000, reward_coin_min: 850, reward_coin_max: 1150, hp: 1850, attack: 82, defense: 24, agility: 8, is_active: true },
    },
  ]

  for (const target of stageTargets) {
    const stage = upsertByFilter("stages", `stage_no=${target.stage.stage_no} && stage_type="${target.stage.stage_type}"`, target.stage)
    upsertStageMonster(stage, target)
  }
}, (app) => {
  // Keep live chapter 2 balance values on rollback.
})
