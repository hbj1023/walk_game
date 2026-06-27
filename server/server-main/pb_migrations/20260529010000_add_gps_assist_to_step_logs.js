migrate((app) => {
  const collection = app.findCollectionByNameOrId("step_sync_logs")

  try {
    collection.fields.getByName("gps_distance_m")
    return
  } catch (_) {}

  collection.fields.add(new NumberField({
    name: "gps_distance_m",
    onlyInt: true,
    min: 0,
  }))
  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("step_sync_logs")

  try {
    collection.fields.removeByName("gps_distance_m")
    app.save(collection)
  } catch (_) {}
})
