migrate((app) => {
  const authenticated = "@request.auth.id != ''"
  const ownCharacter = "character.user = @request.auth.id"

  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.list !== undefined) collection.listRule = rules.list
    if (rules.view !== undefined) collection.viewRule = rules.view
    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update
    if (rules["delete"] !== undefined) collection.deleteRule = rules["delete"]

    app.save(collection)
  }

  setRules("characters", {
    list: authenticated,
    view: authenticated,
    create: authenticated,
    update: authenticated,
  })
  setRules("character_stats", {
    list: authenticated,
    view: authenticated,
    update: ownCharacter,
  })
  setRules("raid_progress", {
    list: authenticated,
    view: authenticated,
    create: authenticated,
    update: authenticated,
  })
  setRules("raid_participants", { update: authenticated })
  setRules("raids", { update: authenticated })
}, (app) => {
  const authenticated = "@request.auth.id != ''"
  const ownCharacter = "character.user = @request.auth.id"

  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.list !== undefined) collection.listRule = rules.list
    if (rules.view !== undefined) collection.viewRule = rules.view
    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update
    if (rules["delete"] !== undefined) collection.deleteRule = rules["delete"]

    app.save(collection)
  }

  setRules("characters", {
    list: authenticated,
    view: authenticated,
    create: authenticated,
    update: authenticated,
  })
  setRules("character_stats", {
    list: authenticated,
    view: authenticated,
    update: ownCharacter,
  })
  setRules("raid_progress", {
    list: authenticated,
    view: authenticated,
    create: authenticated,
    update: authenticated,
  })
  setRules("raid_participants", { update: null })
  setRules("raids", { update: "@request.auth.id != ''" })
})
