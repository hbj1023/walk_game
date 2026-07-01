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

  const monsters = [
    {
      key: "spore",
      name: "포자 버섯병사",
      monster_type: "normal",
      required_distance_min_m: 3200,
      required_distance_max_m: 4300,
      reward_coin_min: 180,
      reward_coin_max: 250,
      hp: 760,
      attack: 42,
      defense: 10,
      agility: 8,
      is_active: true,
    },
    {
      key: "thorn",
      name: "가시 버섯병사",
      monster_type: "normal",
      required_distance_min_m: 3800,
      required_distance_max_m: 5000,
      reward_coin_min: 220,
      reward_coin_max: 300,
      hp: 880,
      attack: 48,
      defense: 14,
      agility: 7,
      is_active: true,
    },
    {
      key: "toxic",
      name: "독버섯 주술사",
      monster_type: "normal",
      required_distance_min_m: 4400,
      required_distance_max_m: 5800,
      reward_coin_min: 260,
      reward_coin_max: 360,
      hp: 1020,
      attack: 56,
      defense: 12,
      agility: 11,
      is_active: true,
    },
    {
      key: "frost",
      name: "서리 버섯병사",
      monster_type: "normal",
      required_distance_min_m: 5200,
      required_distance_max_m: 6800,
      reward_coin_min: 320,
      reward_coin_max: 430,
      hp: 1180,
      attack: 64,
      defense: 16,
      agility: 9,
      is_active: true,
    },
    {
      key: "elder",
      name: "장로 포자왕",
      monster_type: "boss",
      required_distance_min_m: 7000,
      required_distance_max_m: 9000,
      reward_coin_min: 650,
      reward_coin_max: 900,
      hp: 1700,
      attack: 78,
      defense: 22,
      agility: 8,
      is_active: true,
    },
  ]

  const monsterByKey = {}
  for (const monster of monsters) {
    const key = monster.key
    const values = {
      name: monster.name,
      monster_type: monster.monster_type,
      required_distance_min_m: monster.required_distance_min_m,
      required_distance_max_m: monster.required_distance_max_m,
      reward_coin_min: monster.reward_coin_min,
      reward_coin_max: monster.reward_coin_max,
      hp: monster.hp,
      attack: monster.attack,
      defense: monster.defense,
      agility: monster.agility,
      is_active: monster.is_active,
    }
    monsterByKey[key] = upsertByFilter(
      "monsters",
      `name="${values.name}" && monster_type="${values.monster_type}"`,
      values,
    )
  }

  const stages = [
    {
      key: "spore",
      stage_no: 6,
      title: "그늘버섯 숲 - 2-1",
      stage_type: "normal",
      monster_count: 1,
      recommended_distance_min_m: 3200,
      recommended_distance_max_m: 4300,
      is_active: true,
      is_boss: false,
    },
    {
      key: "thorn",
      stage_no: 7,
      title: "그늘버섯 숲 - 2-2",
      stage_type: "normal",
      monster_count: 1,
      recommended_distance_min_m: 3800,
      recommended_distance_max_m: 5000,
      is_active: true,
      is_boss: false,
    },
    {
      key: "toxic",
      stage_no: 8,
      title: "그늘버섯 숲 - 2-3",
      stage_type: "normal",
      monster_count: 1,
      recommended_distance_min_m: 4400,
      recommended_distance_max_m: 5800,
      is_active: true,
      is_boss: false,
    },
    {
      key: "frost",
      stage_no: 9,
      title: "그늘버섯 숲 - 2-4",
      stage_type: "normal",
      monster_count: 1,
      recommended_distance_min_m: 5200,
      recommended_distance_max_m: 6800,
      is_active: true,
      is_boss: false,
    },
    {
      key: "elder",
      stage_no: 10,
      title: "그늘버섯 숲 - 2-5",
      stage_type: "boss",
      monster_count: 1,
      recommended_distance_min_m: 7000,
      recommended_distance_max_m: 9000,
      is_active: true,
      is_boss: true,
    },
  ]

  for (const stageValues of stages) {
    const key = stageValues.key
    const isBoss = stageValues.is_boss
    const values = {
      stage_no: stageValues.stage_no,
      title: stageValues.title,
      stage_type: stageValues.stage_type,
      monster_count: stageValues.monster_count,
      recommended_distance_min_m: stageValues.recommended_distance_min_m,
      recommended_distance_max_m: stageValues.recommended_distance_max_m,
      is_active: stageValues.is_active,
    }
    const stage = upsertByFilter(
      "stages",
      `stage_no=${values.stage_no} && stage_type="${values.stage_type}"`,
      values,
    )
    upsertByFilter("stage_monsters", `stage="${stage.id}" && spawn_order=1`, {
      stage: stage.id,
      monster: monsterByKey[key].id,
      spawn_order: 1,
      is_boss: isBoss,
    })
  }
}, (app) => {
  // Keep live game content on rollback.
})
