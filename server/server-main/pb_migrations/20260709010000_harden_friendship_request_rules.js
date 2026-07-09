migrate((app) => {
  const collection = app.findCollectionByNameOrId("friendships")
  const ownFriendship = "user_low = @request.auth.id || user_high = @request.auth.id"
  const createOwnRequest = [
    "requested_by_user = @request.auth.id",
    "(user_low = @request.auth.id || user_high = @request.auth.id)",
  ].join(" && ")

  collection.listRule = ownFriendship
  collection.viewRule = ownFriendship
  collection.createRule = createOwnRequest
  collection.updateRule = ownFriendship
  app.save(collection)
}, (app) => {
  try {
    const collection = app.findCollectionByNameOrId("friendships")
    collection.listRule = "user_low = @request.auth.id || user_high = @request.auth.id"
    collection.viewRule = "user_low = @request.auth.id || user_high = @request.auth.id"
    collection.createRule = "requested_by_user = @request.auth.id"
    collection.updateRule = "user_low = @request.auth.id || user_high = @request.auth.id"
    app.save(collection)
  } catch (_) {}
})
