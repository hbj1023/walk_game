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

  setRules("purchase_logs", {
    list: authenticated,
    view: ownCharacter,
    create: ownCharacter,
  })
  setRules("owned_equipments", { create: ownCharacter })
  setRules("character_consumables", { create: ownCharacter })
}, (app) => {
  for (const collectionName of [
    "purchase_logs",
    "owned_equipments",
    "character_consumables",
  ]) {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      collection.createRule = null
      if (collectionName === "purchase_logs") {
        collection.listRule = null
        collection.viewRule = null
      }
      app.save(collection)
    } catch (_) {}
  }
})
