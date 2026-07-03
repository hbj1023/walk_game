migrate((app) => {
  const collection = app.findCollectionByNameOrId("daily_step_summaries")

  try {
    collection.fields.getByName("offline_attack_count_earned")
  } catch (_) {
    collection.fields.add(new NumberField({
      name: "offline_attack_count_earned",
      onlyInt: true,
      min: 0,
    }))
  }

  try {
    collection.fields.getByName("offline_attack_count_lost")
  } catch (_) {
    collection.fields.add(new NumberField({
      name: "offline_attack_count_lost",
      onlyInt: true,
      min: 0,
    }))
  }

  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("daily_step_summaries")

  try {
    collection.fields.removeByName("offline_attack_count_earned")
  } catch (_) {}

  try {
    collection.fields.removeByName("offline_attack_count_lost")
  } catch (_) {}

  app.save(collection)
})
