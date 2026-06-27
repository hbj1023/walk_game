migrate((app) => {
  const renameLegacyUserMissions = () => {
    try {
      app.findCollectionByNameOrId("user_missions")
      return
    } catch (_) {}

    try {
      const collection = app.findCollectionByNameOrId("Base_collection")
      collection.name = "user_missions"
      app.save(collection)
    } catch (_) {}
  }

  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.list !== undefined) collection.listRule = rules.list
    if (rules.view !== undefined) collection.viewRule = rules.view
    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update
    if (rules["delete"] !== undefined) collection.deleteRule = rules["delete"]

    app.save(collection)
  }

  renameLegacyUserMissions()

  const authenticated = "@request.auth.id != ''"
  const ownUser = "user = @request.auth.id"
  const ownCharacter = "character.user = @request.auth.id"

  setRules("missions", { list: authenticated, view: authenticated })
  setRules("user_missions", { list: ownUser, view: ownUser, update: ownUser })
  setRules("reward_logs", { list: ownCharacter, view: ownCharacter, create: ownCharacter })
}, (app) => {
  for (const collectionName of ["missions", "user_missions", "reward_logs"]) {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      collection.listRule = null
      collection.viewRule = null
      if (collectionName === "user_missions" || collectionName === "reward_logs") {
        collection.updateRule = null
        collection.createRule = null
      }
      app.save(collection)
    } catch (_) {}
  }
})
