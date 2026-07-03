migrate((app) => {
  const collection = app.findCollectionByNameOrId("item_templates")
  const weaponTypes = ["sword", "axe", "spear", "dagger", "greatsword"]

  try {
    const field = collection.fields.getByName("weapon_type")
    let changed = false
    for (const weaponType of weaponTypes) {
      if (!field.values.includes(weaponType)) {
        field.values.push(weaponType)
        changed = true
      }
    }
    if (changed) app.save(collection)
  } catch (_) {
    collection.fields.add(new SelectField({
      name: "weapon_type",
      maxSelect: 1,
      values: weaponTypes,
    }))
    app.save(collection)
  }

  const swordTemplates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && equipment_slot="sword"`,
    "",
    500,
    0,
  )
  for (const template of swordTemplates) {
    if (template.get("weapon_type")) continue
    template.set("weapon_type", "sword")
    app.save(template)
  }
}, (app) => {
  // Keep weapon_type because chapter 2 weapon styles depend on it.
})
