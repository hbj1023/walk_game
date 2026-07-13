const bossTicketName = "5스테이지 보스 입장권"
const bossTicketFragmentName = "보스 입장권 조각"

const upsertByFilter = (app, collectionName, filter, values) => {
  const collection = app.findCollectionByNameOrId(collectionName)
  const existing = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
  const record = existing.length > 0 ? existing[0] : new Record(collection)
  for (const [key, value] of Object.entries(values)) {
    record.set(key, value)
  }
  app.save(record)
  return record
}

const ensureNumberField = (collection, name, onlyInt) => {
  try {
    collection.fields.getByName(name)
  } catch (_) {
    collection.fields.add(new NumberField({
      name,
      onlyInt,
      min: 0,
    }))
  }
}

const findTemplateByName = (app, name) => {
  const records = app.findRecordsByFilter("item_templates", `name="${name}"`, "", 1, 0)
  return records.length > 0 ? records[0] : null
}

const syncBossTicketShopPrice = (app, priceCoin) => {
  const ticket = findTemplateByName(app, bossTicketName)
  if (!ticket) return

  ticket.set("price_coin", priceCoin)
  ticket.set(
    "description",
    priceCoin === 0
      ? "5스테이지 보스에게 도전할 때 필요한 입장권입니다. 보스 입장권 조각 10개로 구매할 수 있습니다."
      : "5스테이지 보스에게 도전할 때 필요한 입장권입니다.",
  )
  app.save(ticket)

  const shopItems = app.findRecordsByFilter("shop_items", `item_template="${ticket.id}"`, "", 500, 0)
  for (const shopItem of shopItems) {
    shopItem.set("price_coin", priceCoin)
    app.save(shopItem)
  }
}

migrate((app) => {
  const daily = app.findCollectionByNameOrId("daily_step_summaries")
  ensureNumberField(daily, "boss_ticket_fragment_earned", true)
  ensureNumberField(daily, "boss_ticket_fragment_distance_remainder_m", false)
  app.save(daily)

  upsertByFilter(app, "item_templates", `name="${bossTicketFragmentName}"`, {
    name: bossTicketFragmentName,
    item_type: "consumable",
    rarity: "common",
    recover_hp: 0,
    base_hp: 0,
    base_attack: 0,
    base_defense: 0,
    base_agility: 0,
    max_stack_quantity: 999,
    price_coin: 0,
    description: "앱을 켜고 걸을 때 얻는 조각입니다. 10개를 모으면 보스 입장권 1장 구매에 사용할 수 있습니다.",
    is_active: true,
  })

  syncBossTicketShopPrice(app, 0)
}, (app) => {
  try {
    const daily = app.findCollectionByNameOrId("daily_step_summaries")
    try {
      daily.fields.removeByName("boss_ticket_fragment_earned")
    } catch (_) {}
    try {
      daily.fields.removeByName("boss_ticket_fragment_distance_remainder_m")
    } catch (_) {}
    app.save(daily)
  } catch (_) {}

  try {
    const fragment = findTemplateByName(app, bossTicketFragmentName)
    if (fragment) {
      fragment.set("is_active", false)
      app.save(fragment)
    }
  } catch (_) {}

  try {
    syncBossTicketShopPrice(app, 250)
  } catch (_) {}
})
