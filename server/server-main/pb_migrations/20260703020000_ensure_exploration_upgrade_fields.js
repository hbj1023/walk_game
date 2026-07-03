migrate((app) => {
  const ensureNumberField = (collectionName, fieldName) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    try {
      collection.fields.getByName(fieldName)
      console.log(`[exploration-fields] ${collectionName}.${fieldName} already exists`)
      return
    } catch (_) {}

    collection.fields.add(new NumberField({
      name: fieldName,
      onlyInt: true,
      min: 0,
    }))
    app.save(collection)
    console.log(`[exploration-fields] added ${collectionName}.${fieldName}`)
  }

  ensureNumberField("characters", "offline_storage_level")
  ensureNumberField("characters", "offline_efficiency_level")
  ensureNumberField("daily_step_summaries", "offline_attack_count_earned")
  ensureNumberField("daily_step_summaries", "offline_attack_count_lost")
}, (app) => {
  // Keep these fields because exploration upgrades and offline walking depend on them.
})
