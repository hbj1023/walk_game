migrate((app) => {
  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.list !== undefined) collection.listRule = rules.list
    if (rules.view !== undefined) collection.viewRule = rules.view
    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update

    app.save(collection)
  }

  const ensureNumberField = (collectionName, fieldName, onlyInt = true) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    try {
      collection.fields.getByName(fieldName)
      return
    } catch (_) {}

    collection.fields.add(new NumberField({
      name: fieldName,
      onlyInt,
    }))
    app.save(collection)
  }

  const setNumberMin = (collectionName, fieldName, min) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const field = collection.fields.getByName(fieldName)
    field.min = min
    app.save(collection)
  }

  const authenticated = "@request.auth.id != ''"
  const ownCharacter = "character.user = @request.auth.id"

  setRules("character_stats", { list: ownCharacter, view: ownCharacter })
  setRules("monsters", { list: authenticated, view: authenticated })
  setRules("stages", { list: authenticated, view: authenticated })
  setRules("stage_monsters", { list: authenticated, view: authenticated })
  setRules("battles", { list: ownCharacter, view: ownCharacter, create: ownCharacter, update: ownCharacter })
  setRules("reward_logs", { create: ownCharacter })
  setRules("resource_transactions", { create: ownCharacter })
  setNumberMin("characters", "current_hp", 0)

  ensureNumberField("monsters", "hp")
  ensureNumberField("monsters", "attack")
  ensureNumberField("monsters", "defense")
  ensureNumberField("monsters", "agility")

  ensureNumberField("battles", "monster_current_hp")
  ensureNumberField("battles", "character_current_hp")
  ensureNumberField("battles", "monster_attack_gauge_m", false)
  ensureNumberField("battles", "current_spawn_order")

  const battles = app.findCollectionByNameOrId("battles")
  try {
    battles.fields.getByName("last_attacked_at")
  } catch (_) {
    battles.fields.add(new DateField({
      name: "last_attacked_at",
    }))
    app.save(battles)
  }
}, (app) => {
  const removeField = (collectionName, fieldName) => {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      collection.fields.removeByName(fieldName)
      app.save(collection)
    } catch (_) {}
  }

  for (const field of ["hp", "attack", "defense", "agility"]) {
    removeField("monsters", field)
  }
  for (const field of ["monster_current_hp", "character_current_hp", "monster_attack_gauge_m", "current_spawn_order", "last_attacked_at"]) {
    removeField("battles", field)
  }
})
