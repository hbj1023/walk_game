migrate((app) => {
  const collection = app.findCollectionByNameOrId("item_templates")
  const fieldNames = ["base_hp", "base_attack", "base_defense", "base_agility"]
  let changed = false

  for (const fieldName of fieldNames) {
    const field = collection.fields.getByName(fieldName)
    if (field.min === null) continue
    field.min = null
    changed = true
  }

  if (changed) app.save(collection)
}, (app) => {
  // Keep relaxed equipment stat ranges on rollback.
})
