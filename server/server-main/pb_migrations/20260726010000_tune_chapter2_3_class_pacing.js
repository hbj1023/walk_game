const weaponBalance = [
  { setKey: "sentinel", nameMarker: "창술사", rarity: "common", attack: 21 },
  { setKey: "sentinel", nameMarker: "창술사", rarity: "rare", attack: 30 },
  { setKey: "shadow", nameMarker: "도적", rarity: "common", attack: 21 },
  { setKey: "shadow", nameMarker: "도적", rarity: "rare", attack: 30 },
  { setKey: "quarry_berserker", nameMarker: "채석단 광전사", rarity: "common", attack: 44 },
  { setKey: "quarry_berserker", nameMarker: "채석단 광전사", rarity: "rare", attack: 56 },
  { setKey: "quarry_spearmaster", nameMarker: "채석단 창술사", rarity: "common", attack: 46 },
  { setKey: "quarry_spearmaster", nameMarker: "채석단 창술사", rarity: "rare", attack: 60 },
  { setKey: "quarry_rogue", nameMarker: "채석단 도적", rarity: "common", attack: 42 },
  { setKey: "quarry_rogue", nameMarker: "채석단 도적", rarity: "rare", attack: 54 },
  { setKey: "riftbreaker", nameMarker: "균열자", rarity: "epic", attack: 88 },
]

const text = (record, field) => {
  try {
    return String(record.get(field) || "").trim()
  } catch (_) {
    return ""
  }
}

migrate((app) => {
  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && is_active=true`,
    "",
    5000,
    0,
  )

  for (const balance of weaponBalance) {
    const matches = templates.filter((template) =>
      (text(template, "set_key") === balance.setKey ||
        text(template, "name").includes(balance.nameMarker)) &&
      text(template, "rarity") === balance.rarity &&
      text(template, "set_piece_type") === "weapon"
    )
    if (matches.length === 0) {
      throw new Error(`${balance.setKey} ${balance.rarity} weapon count=${matches.length}`)
    }
    for (const template of matches) {
      template.set("base_attack", balance.attack)
      const description = text(template, "description")
      if (description) {
        template.set(
          "description",
          description.replace(/공격력\s*\+\d+/, `공격력 +${balance.attack}`),
        )
      }
      app.save(template)
    }
  }

  const golems = app.findRecordsByFilter(
    "monsters",
    `monster_type="raid" && name="골렘" && is_active=true`,
    "",
    10,
    0,
  )
  if (golems.length !== 1) {
    throw new Error(`active golem count=${golems.length}`)
  }
  golems[0].set("hp", 3400)
  golems[0].set("attack", 100)
  golems[0].set("defense", 40)
  app.save(golems[0])

  console.log("[chapter-balance] normalized slow weapon pacing and set golem HP to 3400")
}, (app) => {
  // The live balance is intentionally preserved on rollback.
})
