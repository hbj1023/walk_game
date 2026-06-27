migrate((app) => {
  const getField = (collection, fieldName) => {
    try {
      return collection.fields.getByName(fieldName) || null
    } catch (_) {
      return null
    }
  }

  const ensureNumberField = (collectionName, fieldName, options = {}) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const field = getField(collection, fieldName)
    let changed = false

    if (!field) {
      collection.fields.add(new NumberField({
        name: fieldName,
        onlyInt: options.onlyInt ?? true,
        min: options.min ?? null,
      }))
      app.save(collection)
      return
    }

    if (options.onlyInt !== undefined && field.onlyInt !== options.onlyInt) {
      field.onlyInt = options.onlyInt
      changed = true
    }
    if (options.min !== undefined && field.min !== options.min) {
      field.min = options.min
      changed = true
    }
    if (changed) app.save(collection)
  }

  const ensureDateField = (collectionName, fieldName) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    if (getField(collection, fieldName)) {
      return
    }

    collection.fields.add(new DateField({ name: fieldName }))
    app.save(collection)
  }

  for (const fieldName of ["hp", "attack", "defense", "agility"]) {
    ensureNumberField("monsters", fieldName, { onlyInt: true, min: 0 })
  }

  ensureNumberField("battles", "monster_current_hp", { onlyInt: true, min: 0 })
  ensureNumberField("battles", "character_current_hp", { onlyInt: true, min: 0 })
  ensureNumberField("battles", "monster_attack_gauge_m", { onlyInt: false, min: 0 })
  ensureNumberField("battles", "current_spawn_order", { onlyInt: true, min: 0 })
  ensureDateField("battles", "last_attacked_at")

  const authenticated = "@request.auth.id != ''"
  const ownCharacter = "character.user = @request.auth.id"

  const battles = app.findCollectionByNameOrId("battles")
  battles.listRule = ownCharacter
  battles.viewRule = ownCharacter
  battles.createRule = ownCharacter
  battles.updateRule = ownCharacter
  app.save(battles)

  const monsters = app.findCollectionByNameOrId("monsters")
  monsters.listRule = authenticated
  monsters.viewRule = authenticated
  app.save(monsters)
}, (app) => {
  // Runtime schema hardening should remain in place on rollback.
})
