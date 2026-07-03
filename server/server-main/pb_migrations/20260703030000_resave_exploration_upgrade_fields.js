migrate((app) => {
  const ensureNumberFields = (collectionName, fieldNames) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    for (const fieldName of fieldNames) {
      try {
        collection.fields.getByName(fieldName)
        console.log(`[exploration-fields-resave] ${collectionName}.${fieldName} already exists`)
      } catch (_) {
        collection.fields.add(new NumberField({
          name: fieldName,
          onlyInt: true,
          min: 0,
        }))
        console.log(`[exploration-fields-resave] added ${collectionName}.${fieldName}`)
      }
    }

    app.save(collection)
    console.log(`[exploration-fields-resave] saved ${collectionName}`)
  }

  ensureNumberFields("characters", [
    "offline_storage_level",
    "offline_efficiency_level",
  ])
  ensureNumberFields("daily_step_summaries", [
    "offline_attack_count_earned",
    "offline_attack_count_lost",
  ])
}, (app) => {
  // Keep these fields because exploration upgrades and offline walking depend on them.
})
