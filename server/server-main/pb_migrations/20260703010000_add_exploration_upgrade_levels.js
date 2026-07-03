migrate((app) => {
  const collection = app.findCollectionByNameOrId("characters")

  try {
    collection.fields.getByName("offline_storage_level")
  } catch (_) {
    collection.fields.add(new NumberField({
      name: "offline_storage_level",
      onlyInt: true,
      min: 0,
    }))
  }

  try {
    collection.fields.getByName("offline_efficiency_level")
  } catch (_) {
    collection.fields.add(new NumberField({
      name: "offline_efficiency_level",
      onlyInt: true,
      min: 0,
    }))
  }

  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("characters")

  try {
    collection.fields.removeByName("offline_storage_level")
  } catch (_) {}

  try {
    collection.fields.removeByName("offline_efficiency_level")
  } catch (_) {}

  app.save(collection)
})
