migrate((app) => {
  const templates = app.findRecordsByFilter("item_templates", `rarity="rare"`, "", 5000, 0)
  for (const template of templates) {
    const name = String(template.get("name") || "")
    if (!name.startsWith("강화된 채석단 ")) continue
    template.set("name", `+${name.slice("강화된 ".length)}`)
    app.save(template)
  }
}, (app) => {
  const templates = app.findRecordsByFilter("item_templates", `rarity="rare"`, "", 5000, 0)
  for (const template of templates) {
    const name = String(template.get("name") || "")
    if (!name.startsWith("+채석단 ")) continue
    template.set("name", `강화된 ${name.slice(1)}`)
    app.save(template)
  }
})
