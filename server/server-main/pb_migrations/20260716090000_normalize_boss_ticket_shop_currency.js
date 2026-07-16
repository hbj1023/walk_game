const bossTicketName = "보스 입장권"
const legacyBossTicketName = "5스테이지 보스 입장권"

const findTemplates = (app, name) =>
  app.findRecordsByFilter("item_templates", `name="${name}"`, "", 100, 0)

migrate((app) => {
  const tickets = [
    ...findTemplates(app, bossTicketName),
    ...findTemplates(app, legacyBossTicketName),
  ]
  if (tickets.length === 0) throw new Error("boss entrance ticket template not found")

  const shops = app.findRecordsByFilter(
    "shops",
    `shop_type="normal" && is_active=true`,
    "",
    100,
    0,
  )
  const shopItemCollection = app.findCollectionByNameOrId("shop_items")

  for (const ticket of tickets) {
    ticket.set("name", bossTicketName)
    ticket.set("item_type", "consumable")
    ticket.set("price_coin", 0)
    ticket.set("description", "찢어진 보스 입장권 10개로 구매할 수 있는 보스 입장권입니다.")
    ticket.set("is_active", true)
    app.save(ticket)

    for (const shop of shops) {
      const existing = app.findRecordsByFilter(
        "shop_items",
        `shop="${shop.id}" && item_template="${ticket.id}"`,
        "",
        1,
        0,
      )
      const shopItem = existing.length > 0
        ? existing[0]
        : new Record(shopItemCollection)
      shopItem.set("shop", shop.id)
      shopItem.set("item_template", ticket.id)
      shopItem.set("price_coin", 0)
      shopItem.set("stock_limit", 0)
      shopItem.set("purchase_limit_per_user", 0)
      shopItem.set("is_active", true)
      app.save(shopItem)
    }
  }

  console.log(`[boss-ticket-shop] normalized ${tickets.length} ticket template(s) to torn-ticket payment`)
}, (app) => {
  // Keep the normalized boss ticket shop currency on rollback.
})
