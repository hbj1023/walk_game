migrate((app) => {
  const renameItems = [
    { from: "초급 검", to: "낡은검" },
    { from: "초급검", to: "낡은검" },
    { from: "레어 검", to: "일반검" },
    { from: "레어검", to: "일반검" },
  ]

  for (const item of renameItems) {
    const records = app.findRecordsByFilter(
      "item_templates",
      `name="${item.from}" && item_type="equipment" && equipment_slot="sword"`,
      "",
      20,
      0,
    )
    for (const record of records) {
      record.set("name", item.to)
      app.save(record)
    }
  }
}, (app) => {
  const renameItems = [
    { from: "낡은검", to: "초급 검", rarity: "common" },
    { from: "일반검", to: "레어 검", rarity: "rare" },
  ]

  for (const item of renameItems) {
    const records = app.findRecordsByFilter(
      "item_templates",
      `name="${item.from}" && item_type="equipment" && equipment_slot="sword" && rarity="${item.rarity}"`,
      "",
      20,
      0,
    )
    for (const record of records) {
      record.set("name", item.to)
      app.save(record)
    }
  }
})
