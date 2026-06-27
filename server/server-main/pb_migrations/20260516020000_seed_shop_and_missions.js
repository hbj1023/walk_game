migrate((app) => {
  const upsertByFilter = (collectionName, filter, values) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const existing = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
    const record = existing.length > 0 ? existing[0] : new Record(collection)
    for (const [key, value] of Object.entries(values)) {
      record.set(key, value)
    }
    app.save(record)
    return record
  }

  const userMissions = app.findCollectionByNameOrId("user_missions")
  userMissions.createRule = "user = @request.auth.id"
  userMissions.updateRule = "user = @request.auth.id"
  app.save(userMissions)

  const missions = [
    { title: "1km 걷기", mission_type: "daily", target_type: "distance", target_value: 1000, reward_coin: 100, is_active: true },
    { title: "3km 걷기", mission_type: "daily", target_type: "distance", target_value: 3000, reward_coin: 250, is_active: true },
    { title: "5km 걷기", mission_type: "daily", target_type: "distance", target_value: 5000, reward_coin: 500, is_active: true },
  ]
  for (const mission of missions) {
    upsertByFilter("missions", `title="${mission.title}"`, mission)
  }

  const potion = upsertByFilter("item_templates", `name="초급 회복 물약"`, {
    name: "초급 회복 물약",
    item_type: "consumable",
    rarity: "common",
    recover_hp: 50,
    base_hp: 0,
    base_attack: 0,
    base_defense: 0,
    base_agility: 0,
    max_stack_quantity: 99,
    price_coin: 30,
    is_active: true,
  })

  const shop = upsertByFilter("shops", `name="기본 상점"`, {
    name: "기본 상점",
    shop_type: "normal",
    is_active: true,
  })

  const itemTemplates = app.findRecordsByFilter(
    "item_templates",
    `is_active=true && (item_type="consumable" || rarity="common")`,
    "item_type,equipment_slot,price_coin,name",
    100,
    0,
  )
  const templateIds = new Set(itemTemplates.map((item) => item.id))
  templateIds.add(potion.id)

  for (const itemTemplateID of templateIds) {
    const itemTemplate = app.findRecordById("item_templates", itemTemplateID)
    const price = Number(itemTemplate.get("price_coin") || 0)
    const values = {
      shop: shop.id,
      item_template: itemTemplate.id,
      price_coin: price,
      is_active: true,
    }
    if (itemTemplate.get("item_type") !== "consumable") {
      values.stock_limit = 1
    }
    upsertByFilter("shop_items", `shop="${shop.id}" && item_template="${itemTemplate.id}"`, values)
  }
}, (app) => {
  // Keep live game content on rollback.
})
