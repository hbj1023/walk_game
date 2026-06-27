migrate((app) => {
  const removeSelectValue = (collectionName, fieldName, value) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const field = collection.fields.getByName(fieldName)
    if (!field.values.includes(value)) {
      return
    }

    field.values = field.values.filter((item) => item !== value)
    app.save(collection)
  }

  const greavesTemplates = app.findRecordsByFilter("item_templates", `equipment_slot="greaves"`, "", 500, 0)
  for (const template of greavesTemplates) {
    const shopItems = app.findRecordsByFilter("shop_items", `item_template="${template.id}"`, "", 500, 0)
    for (const shopItem of shopItems) {
      shopItem.set("is_active", false)
      app.save(shopItem)
    }

    template.set("equipment_slot", "")
    template.set("is_active", false)
    app.save(template)
  }

  const slotBalances = app.findRecordsByFilter("equipment_slot_balances", `slot_type="greaves"`, "", 500, 0)
  for (const balance of slotBalances) {
    balance.set("slot_type", "")
    balance.set("description", "Removed unused greaves slot.")
    app.save(balance)
  }

  removeSelectValue("item_templates", "equipment_slot", "greaves")
  removeSelectValue("equipment_slot_balances", "slot_type", "greaves")
}, (app) => {
  // Keep the greaves slot removed on rollback.
})
