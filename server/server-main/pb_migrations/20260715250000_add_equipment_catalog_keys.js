const ensureCatalogKeyField = (app) => {
  const collection = app.findCollectionByNameOrId("item_templates")
  let fieldExists = true
  try {
    collection.fields.getByName("catalog_key")
  } catch (error) {
    fieldExists = false
  }
  if (!fieldExists) {
    collection.fields.add(new TextField({ name: "catalog_key", max: 120 }))
    app.save(collection)
  }
}

migrate((app) => {
  ensureCatalogKeyField(app)
}, (app) => {
  // Keep immutable catalog identities on rollback.
})
