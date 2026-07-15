const bossTicketOldName = "5\uc2a4\ud14c\uc774\uc9c0 \ubcf4\uc2a4 \uc785\uc7a5\uad8c"
const bossTicketName = "\ubcf4\uc2a4 \uc785\uc7a5\uad8c"
const bossTicketPrice = 300

const findTicket = (app) => {
  for (const name of [bossTicketName, bossTicketOldName]) {
    const records = app.findRecordsByFilter("item_templates", `name="${name}"`, "", 10, 0)
    if (records.length > 0) return records[0]
  }
  return null
}

migrate((app) => {
  const ticket = findTicket(app)
  if (!ticket) throw new Error("boss entrance ticket template not found")

  ticket.set("name", bossTicketName)
  ticket.set("price_coin", bossTicketPrice)
  ticket.set("description", "\ubaa8\ub4e0 \ubcf4\uc2a4 \uc804\ud22c\uc5d0 \uacf5\ud1b5\uc73c\ub85c \uc0ac\uc6a9\ud558\ub294 \uc785\uc7a5\uad8c\uc785\ub2c8\ub2e4.")
  ticket.set("is_active", true)
  app.save(ticket)

  const shopItems = app.findRecordsByFilter(
    "shop_items",
    `item_template="${ticket.id}"`,
    "",
    100,
    0,
  )
  for (const item of shopItems) {
    item.set("price_coin", bossTicketPrice)
    item.set("stock_limit", 0)
    item.set("purchase_limit_per_user", 0)
    item.set("is_active", true)
    app.save(item)
  }
}, (app) => {
  // Keep the generic ticket name and coin price on rollback.
})
