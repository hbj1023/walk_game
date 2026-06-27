migrate((app) => {
  const collection = app.findCollectionByNameOrId("users")
  const authenticated = "@request.auth.id != ''"

  collection.listRule = authenticated
  collection.viewRule = authenticated

  app.save(collection)
}, (app) => {
  try {
    const collection = app.findCollectionByNameOrId("users")

    collection.listRule = "id = @request.auth.id"
    collection.viewRule = "id = @request.auth.id"

    app.save(collection)
  } catch (_) {}
})
