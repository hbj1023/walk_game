migrate((app) => {
  const collection = app.findCollectionByNameOrId("characters")
  try {
    collection.fields.getByName("stat_exp")
    return
  } catch (_) {}

  collection.fields.add(new NumberField({
    name: "stat_exp",
    onlyInt: true,
  }))
  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("characters")
  try {
    collection.fields.removeByName("stat_exp")
    app.save(collection)
  } catch (_) {}
})
