migrate((app) => {
  const collection = app.findCollectionByNameOrId("monsters")
  let changed = false

  const ensureNumberField = (name) => {
    try {
      collection.fields.getByName(name)
      return
    } catch (_) {}

    collection.fields.add(new NumberField({
      name,
      onlyInt: true,
      min: 0,
    }))
    changed = true
  }

  ensureNumberField("hp")
  ensureNumberField("attack")
  ensureNumberField("defense")
  ensureNumberField("agility")

  if (changed) {
    app.save(collection)
  }
}, (app) => {
  // Keep fields on rollback to avoid deleting live monster battle data.
})
