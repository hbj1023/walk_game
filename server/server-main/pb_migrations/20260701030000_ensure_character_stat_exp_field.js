migrate((app) => {
  const collection = app.findCollectionByNameOrId("characters")

  try {
    const field = collection.fields.getByName("stat_exp")
    let changed = false
    if (field.onlyInt !== true) {
      field.onlyInt = true
      changed = true
    }
    if (field.min !== 0) {
      field.min = 0
      changed = true
    }
    if (changed) app.save(collection)
  } catch (_) {
    collection.fields.add(new NumberField({
      name: "stat_exp",
      onlyInt: true,
      min: 0,
    }))
    app.save(collection)
  }

  const records = app.findRecordsByFilter("characters", "level > 1", "", 500, 0)
  for (const character of records) {
    const level = Number(character.get("level") || 1)
    const current = Number(character.get("stat_exp") || 0)
    let minimum = 0

    for (let nextLevel = 2; nextLevel <= level; nextLevel++) {
      minimum += 40 + Math.floor((nextLevel - 1) / 5) * 10
    }

    if (current >= minimum) continue

    character.set("stat_exp", minimum)
    app.save(character)
  }
}, (app) => {
  // Keep stat_exp because gameplay now depends on this field.
})
