migrate((app) => {
  const collection = app.findCollectionByNameOrId("shop_items")
  const authenticated = "@request.auth.id != ''"

  collection.createRule = authenticated
  collection.updateRule = authenticated

  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("shop_items")

  collection.createRule = null
  collection.updateRule = null

  app.save(collection)
})
