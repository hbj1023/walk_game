migrate((app) => {
  const collection = app.findCollectionByNameOrId("daily_step_summaries")

  try {
    collection.fields.getByName("attack_distance_remainder_m")
    return
  } catch (_) {}

  collection.fields.add(new NumberField({
    name: "attack_distance_remainder_m",
  }))
  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("daily_step_summaries")

  try {
    collection.fields.removeByName("attack_distance_remainder_m")
    app.save(collection)
  } catch (_) {}
})
