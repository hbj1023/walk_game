migrate((app) => {
  const setReadRules = (collectionName, rule) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    collection.listRule = rule
    collection.viewRule = rule
    app.save(collection)
  }

  const authenticated = "@request.auth.id != ''"

  setReadRules("shops", authenticated)
  setReadRules("shop_items", authenticated)
}, (app) => {
  for (const collectionName of ["shops", "shop_items"]) {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      collection.listRule = null
      collection.viewRule = null
      app.save(collection)
    } catch (_) {}
  }
})
