const oldFragmentName = "보스 입장권 조각"
const tornTicketName = "찢어진 보스 입장권"
const bossTicketName = "보스 입장권"

migrate((app) => {
  const oldTemplates = app.findRecordsByFilter("item_templates", `name="${oldFragmentName}"`, "", 50, 0)
  const newTemplates = app.findRecordsByFilter("item_templates", `name="${tornTicketName}"`, "", 50, 0)
  const templates = [...newTemplates, ...oldTemplates]
  if (templates.length === 0) throw new Error("boss ticket fragment template not found")

  for (const template of templates) {
    template.set("name", tornTicketName)
    template.set("item_type", "consumable")
    template.set("rarity", "common")
    template.set("max_stack_quantity", 999999)
    template.set("price_coin", 0)
    template.set("description", "앱을 켜고 걷거나 스테이지를 클리어할 때 얻을 수 있습니다. 10개로 보스 입장권 1장을 구매할 수 있습니다.")
    template.set("is_active", true)
    app.save(template)
  }

  const bossTickets = app.findRecordsByFilter("item_templates", `name="${bossTicketName}"`, "", 50, 0)
  for (const ticket of bossTickets) {
    ticket.set("description", "보스에게 도전할 때 필요한 입장권입니다. 찢어진 보스 입장권 10개로 구매할 수 있습니다.")
    ticket.set("price_coin", 0)
    ticket.set("is_active", true)
    app.save(ticket)
  }

  console.log("[torn-boss-ticket] renamed the existing fragment currency while preserving owned quantities")
}, (app) => {
  // Keep the torn boss ticket currency name on rollback.
})
