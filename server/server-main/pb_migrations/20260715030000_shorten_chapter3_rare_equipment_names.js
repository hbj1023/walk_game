const chapter3SetKeys = [
  "quarry_swordsman",
  "quarry_berserker",
  "quarry_spearmaster",
  "quarry_rogue",
  "quarry_knight",
]

migrate((app) => {
  for (const setKey of chapter3SetKeys) {
    const templates = app.findRecordsByFilter(
      "item_templates",
      `set_key="${setKey}" && rarity="rare"`,
      "",
      100,
      0,
    )
    for (const template of templates) {
      const name = String(template.get("name") || "")
      if (!name.startsWith("강화된 ")) continue
      template.set("name", `+${name.slice("강화된 ".length)}`)
      app.save(template)
    }
  }
}, (app) => {
  for (const setKey of chapter3SetKeys) {
    const templates = app.findRecordsByFilter(
      "item_templates",
      `set_key="${setKey}" && rarity="rare"`,
      "",
      100,
      0,
    )
    for (const template of templates) {
      const name = String(template.get("name") || "")
      if (!name.startsWith("+채석단 ")) continue
      template.set("name", `강화된 ${name.slice(1)}`)
      app.save(template)
    }
  }
})
