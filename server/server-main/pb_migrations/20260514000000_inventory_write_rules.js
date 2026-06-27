migrate((app) => {
  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update
    if (rules["delete"] !== undefined) collection.deleteRule = rules["delete"]

    app.save(collection)
  }

  const ownCharacter = "character.user = @request.auth.id"

  setRules("owned_equipments", { update: ownCharacter })
  setRules("character_consumables", { update: ownCharacter })
  setRules("character_equipments", { create: ownCharacter, "delete": ownCharacter })
}, (app) => {
  for (const collectionName of [
    "owned_equipments",
    "character_consumables",
    "character_equipments",
  ]) {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      collection.createRule = null
      collection.updateRule = null
      collection.deleteRule = null
      app.save(collection)
    } catch (_) {}
  }
})
