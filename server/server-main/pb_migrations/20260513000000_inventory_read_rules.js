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

  setRules("item_templates", { list: authenticated, view: authenticated })
  setRules("equipment_slot_balances", { list: authenticated, view: authenticated })
  setRules("equipment_rarity_balances", { list: authenticated, view: authenticated })
  setRules("owned_equipments", { list: ownCharacter, view: ownCharacter, update: ownCharacter })
  setRules("character_consumables", { list: ownCharacter, view: ownCharacter, update: ownCharacter })
  setRules("character_equipments", { list: ownCharacter, view: ownCharacter, create: ownCharacter, "delete": ownCharacter })
}, (app) => {
  const clearRules = (collectionName) => {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      collection.listRule = null
      collection.viewRule = null
      collection.createRule = null
      collection.updateRule = null
      collection.deleteRule = null
      app.save(collection)
    } catch (_) {}
  }

  for (const name of [
    "item_templates",
    "equipment_slot_balances",
    "equipment_rarity_balances",
    "owned_equipments",
    "character_consumables",
    "character_equipments",
  ]) {
    clearRules(name)
  }
})
