const ancientQuarryContent = [
  {
    stageNo: 11,
    title: "고대 채석장 - 3-1",
    stageType: "normal",
    monster: {
      name: "금이 간 석상병",
      type: "normal",
      hp: 250,
      attack: 60,
      defense: 28,
      agility: 4,
      distanceMin: 5200,
      distanceMax: 6500,
      coinMin: 450,
      coinMax: 600,
    },
  },
  {
    stageNo: 12,
    title: "고대 채석장 - 3-2",
    stageType: "normal",
    monster: {
      name: "광맥 굴착 골렘",
      type: "normal",
      hp: 300,
      attack: 70,
      defense: 36,
      agility: 6,
      distanceMin: 5800,
      distanceMax: 7200,
      coinMin: 560,
      coinMax: 730,
    },
  },
  {
    stageNo: 13,
    title: "고대 채석장 - 3-3",
    stageType: "normal",
    monster: {
      name: "룬 각인 수호자",
      type: "normal",
      hp: 360,
      attack: 80,
      defense: 44,
      agility: 5,
      distanceMin: 6400,
      distanceMax: 8000,
      coinMin: 680,
      coinMax: 880,
    },
  },
  {
    stageNo: 14,
    title: "고대 채석장 - 3-4",
    stageType: "normal",
    monster: {
      name: "고대 파쇄 거인",
      type: "normal",
      hp: 450,
      attack: 94,
      defense: 54,
      agility: 3,
      distanceMin: 7200,
      distanceMax: 9000,
      coinMin: 850,
      coinMax: 1100,
    },
  },
  {
    stageNo: 15,
    title: "고대 채석장 - 3-5",
    stageType: "boss",
    monster: {
      name: "거석왕 탈로스",
      type: "boss",
      hp: 760,
      attack: 110,
      defense: 68,
      agility: 2,
      distanceMin: 9000,
      distanceMax: 11000,
      coinMin: 1400,
      coinMax: 1900,
    },
  },
]

const upsertByFilter = (app, collectionName, filter, values) => {
  const collection = app.findCollectionByNameOrId(collectionName)
  const existing = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
  const record = existing.length > 0 ? existing[0] : new Record(collection)
  for (const [key, value] of Object.entries(values)) record.set(key, value)
  app.save(record)
  return record
}

migrate((app) => {
  for (const content of ancientQuarryContent) {
    const monsterValues = {
      name: content.monster.name,
      monster_type: content.monster.type,
      required_distance_min_m: content.monster.distanceMin,
      required_distance_max_m: content.monster.distanceMax,
      reward_coin_min: content.monster.coinMin,
      reward_coin_max: content.monster.coinMax,
      hp: content.monster.hp,
      attack: content.monster.attack,
      defense: content.monster.defense,
      agility: content.monster.agility,
      is_active: true,
    }
    const monster = upsertByFilter(
      app,
      "monsters",
      `name="${content.monster.name}" && monster_type="${content.monster.type}"`,
      monsterValues,
    )

    const stageValues = {
      stage_no: content.stageNo,
      title: content.title,
      stage_type: content.stageType,
      monster_count: 1,
      recommended_distance_min_m: content.monster.distanceMin,
      recommended_distance_max_m: content.monster.distanceMax,
      is_active: true,
    }
    const stage = upsertByFilter(
      app,
      "stages",
      `stage_no=${content.stageNo} && stage_type="${content.stageType}"`,
      stageValues,
    )

    upsertByFilter(app, "stage_monsters", `stage="${stage.id}" && spawn_order=1`, {
      stage: stage.id,
      monster: monster.id,
      spawn_order: 1,
      is_boss: content.stageType === "boss",
    })
  }
}, (app) => {
  // Keep live chapter 3 content on rollback.
})
