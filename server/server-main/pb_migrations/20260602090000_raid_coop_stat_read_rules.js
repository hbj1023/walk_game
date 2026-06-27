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

  const authenticated = "@request.auth.id != ''"
  const ownCharacter = "character.user = @request.auth.id"

  setRules("raids", { update: authenticated })
  setRules("character_stats", { list: authenticated, view: authenticated, update: ownCharacter })
  setRules("owned_equipments", { list: authenticated, view: authenticated, update: ownCharacter })
  setRules("character_equipments", {
    list: authenticated,
    view: authenticated,
    create: ownCharacter,
    "delete": ownCharacter,
  })
}, (app) => {
  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.list !== undefined) collection.listRule = rules.list
    if (rules.view !== undefined) collection.viewRule = rules.view
    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update
    if (rules["delete"] !== undefined) collection.deleteRule = rules["delete"]

    app.save(collection)
  }

  const ownCharacter = "character.user = @request.auth.id"

  setRules("raids", { update: null })
  setRules("character_stats", { list: ownCharacter, view: ownCharacter, update: "@request.auth.id != ''" })
  setRules("owned_equipments", { list: ownCharacter, view: ownCharacter, update: ownCharacter })
  setRules("character_equipments", {
    list: ownCharacter,
    view: ownCharacter,
    create: ownCharacter,
    "delete": ownCharacter,
  })
})
