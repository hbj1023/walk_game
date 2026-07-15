const essentialConsumables = [
  {
    name: "초급 회복 물약",
    rarity: "common",
    recoverHp: 50,
    price: 40,
    description: "HP를 50 회복합니다.",
    sellInShop: true,
  },
  {
    name: "중급 회복 물약",
    rarity: "rare",
    recoverHp: 120,
    price: 110,
    description: "HP를 120 회복합니다.",
    sellInShop: true,
  },
  {
    name: "고급 회복 물약",
    rarity: "epic",
    recoverHp: 250,
    price: 240,
    description: "HP를 250 회복합니다.",
    sellInShop: true,
  },
  {
    name: "5스테이지 보스 입장권",
    rarity: "epic",
    recoverHp: 0,
    price: 0,
    description: "보스에게 도전할 때 필요한 입장권입니다. 보스 입장권 조각 10개로 구매할 수 있습니다.",
    sellInShop: true,
  },
  {
    name: "보스 입장권 조각",
    rarity: "common",
    recoverHp: 0,
    price: 0,
    maxStack: 999,
    description: "앱을 켜고 걸을 때 얻는 조각입니다. 10개를 모으면 보스 입장권 1장 구매에 사용할 수 있습니다.",
    sellInShop: false,
  },
]

const findByName = (app, name) => {
  const records = app.findRecordsByFilter("item_templates", `name="${name}"`, "", 1, 0)
  return records.length > 0 ? records[0] : null
}

const restoreTemplate = (app, definition) => {
  const collection = app.findCollectionByNameOrId("item_templates")
  const template = findByName(app, definition.name) || new Record(collection)
  template.set("name", definition.name)
  template.set("item_type", "consumable")
  template.set("rarity", definition.rarity)
  template.set("recover_hp", definition.recoverHp)
  template.set("base_hp", 0)
  template.set("base_attack", 0)
  template.set("base_defense", 0)
  template.set("base_agility", 0)
  template.set("max_stack_quantity", definition.maxStack || 99)
  template.set("price_coin", definition.price)
  template.set("description", definition.description)
  template.set("is_active", true)
  app.save(template)
  return template
}

const restoreShopItem = (app, shop, template, price) => {
  const collection = app.findCollectionByNameOrId("shop_items")
  const records = app.findRecordsByFilter(
    "shop_items",
    `shop="${shop.id}" && item_template="${template.id}"`,
    "",
    1,
    0,
  )
  const item = records.length > 0 ? records[0] : new Record(collection)
  item.set("shop", shop.id)
  item.set("item_template", template.id)
  item.set("price_coin", price)
  item.set("stock_limit", 0)
  item.set("purchase_limit_per_user", 0)
  item.set("is_active", true)
  app.save(item)
}

migrate((app) => {
  const shops = app.findRecordsByFilter("shops", `shop_type="normal" && is_active=true`, "", 100, 0)

  for (const definition of essentialConsumables) {
    const template = restoreTemplate(app, definition)
    if (!definition.sellInShop) {
      const shopItems = app.findRecordsByFilter("shop_items", `item_template="${template.id}"`, "", 100, 0)
      for (const shopItem of shopItems) {
        shopItem.set("is_active", false)
        app.save(shopItem)
      }
      continue
    }
    for (const shop of shops) {
      restoreShopItem(app, shop, template, definition.price)
    }
  }
}, (app) => {
  // Essential consumables remain available on rollback.
})
