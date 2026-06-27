migrate((app) => {
  const ensureNumberField = (collectionName, fieldName, options = {}) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    try {
      collection.fields.getByName(fieldName)
      return
    } catch (_) {}

    collection.fields.add(new NumberField({
      name: fieldName,
      onlyInt: options.onlyInt ?? false,
      min: options.min ?? 0,
    }))
    app.save(collection)
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

  ensureNumberField("raid_progress", "distance_since_last_monster_attack_m")
  ensureNumberField("raid_progress", "total_monster_attack_cycles", { onlyInt: true })

  const monsters = [
    {
      name: "골렘",
      monster_type: "raid",
      required_distance_min_m: 0,
      required_distance_max_m: 0,
      reward_coin_min: 500,
      reward_coin_max: 700,
      hp: 140,
      attack: 12,
      defense: 5,
      agility: 1,
      is_active: true,
    },
    {
      name: "와이번",
      monster_type: "raid",
      required_distance_min_m: 0,
      required_distance_max_m: 0,
      reward_coin_min: 650,
      reward_coin_max: 900,
      hp: 120,
      attack: 16,
      defense: 2,
      agility: 18,
      is_active: true,
    },
  ]

  for (const monster of monsters) {
    upsertByFilter("monsters", `name="${monster.name}" && monster_type="raid"`, monster)
  }
}, (app) => {
  // Keep raid boss data and progress fields on rollback to avoid deleting live raid state.
})
