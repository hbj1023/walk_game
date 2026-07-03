migrate((app) => {
  const recreateNumberFields = (collectionName, fieldNames) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    for (const fieldName of fieldNames) {
      try {
        collection.fields.removeByName(fieldName)
        console.log(`[exploration-fields-recreate] removed ${collectionName}.${fieldName}`)
      } catch (_) {
        console.log(`[exploration-fields-recreate] ${collectionName}.${fieldName} was missing`)
      }

      collection.fields.add(new NumberField({
        name: fieldName,
        onlyInt: true,
        min: 0,
      }))
      console.log(`[exploration-fields-recreate] added ${collectionName}.${fieldName}`)
    }

    app.save(collection)
    console.log(`[exploration-fields-recreate] saved ${collectionName}`)
  }

  recreateNumberFields("characters", [
    "offline_storage_level",
    "offline_efficiency_level",
  ])
  recreateNumberFields("daily_step_summaries", [
    "offline_attack_count_earned",
    "offline_attack_count_lost",
  ])
}, (app) => {
  // Keep these fields because exploration upgrades and offline walking depend on them.
})
