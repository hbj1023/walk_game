migrate((app) => {
  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.list !== undefined) collection.listRule = rules.list
    if (rules.view !== undefined) collection.viewRule = rules.view
    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update
    if (rules["delete"] !== undefined) collection.deleteRule = rules["delete"]

    app.save(collection)
  }

  const ownFriendship = "user_low = @request.auth.id || user_high = @request.auth.id"
  const createOwnRequest = "requested_by_user = @request.auth.id"

  setRules("friendships", {
    list: ownFriendship,
    view: ownFriendship,
    create: createOwnRequest,
    update: ownFriendship,
  })
}, (app) => {
  try {
    const collection = app.findCollectionByNameOrId("friendships")
    collection.listRule = null
    collection.viewRule = null
    collection.createRule = null
    collection.updateRule = null
    collection.deleteRule = null
    app.save(collection)
  } catch (_) {}
})
