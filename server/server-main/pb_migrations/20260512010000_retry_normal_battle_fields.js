migrate((app) => {
  const addNumberFields = (collectionName, fields) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    let changed = false

    for (const field of fields) {
      try {
        collection.fields.getByName(field.name)
        continue
      } catch (_) {}

      collection.fields.add(new NumberField({
        name: field.name,
        onlyInt: field.onlyInt ?? true,
      }))
      changed = true
    }

    if (changed) {
      app.save(collection)
    }
  }

  addNumberFields("monsters", [
    { name: "hp" },
    { name: "attack" },
    { name: "defense" },
    { name: "agility" },
  ])

  addNumberFields("battles", [
    { name: "monster_current_hp" },
    { name: "character_current_hp" },
    { name: "monster_attack_gauge_m", onlyInt: false },
    { name: "current_spawn_order" },
  ])

  const battles = app.findCollectionByNameOrId("battles")
  try {
    battles.fields.getByName("last_attacked_at")
  } catch (_) {
    battles.fields.add(new DateField({
      name: "last_attacked_at",
    }))
    app.save(battles)
  }

  const characters = app.findCollectionByNameOrId("characters")
  const currentHp = characters.fields.getByName("current_hp")
  currentHp.min = 0
  app.save(characters)
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
