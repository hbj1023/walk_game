migrate((app) => {
  const upsertByFilter = (collectionName, filter, values) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const existing = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
    const record = existing.length > 0 ? existing[0] : new Record(collection)
    for (const [key, value] of Object.entries(values)) {
      record.set(key, value)
    }
    app.save(record)
  }

  upsertByFilter("monsters", `name="골렘" && monster_type="raid"`, {
    name: "골렘",
    monster_type: "raid",
    required_distance_min_m: 0,
    required_distance_max_m: 0,
    reward_coin_min: 1200,
    reward_coin_max: 1600,
    hp: 1800,
    attack: 42,
    defense: 18,
    agility: 3,
    is_active: true,
  })

  upsertByFilter("monsters", `name="와이번" && monster_type="raid"`, {
    name: "와이번",
    monster_type: "raid",
    required_distance_min_m: 0,
    required_distance_max_m: 0,
    reward_coin_min: 0,
    reward_coin_max: 0,
    hp: 120,
    attack: 16,
    defense: 2,
    agility: 18,
    is_active: true,
  })
}, (app) => {
  // Keep the latest raid balance on rollback.
})
