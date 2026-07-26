const weaponBalance = {
  sentinel: { common: 21, rare: 30 },
  shadow: { common: 21, rare: 30 },
  quarry_berserker: { common: 44, rare: 56 },
  quarry_spearmaster: { common: 46, rare: 60 },
  quarry_rogue: { common: 42, rare: 54 },
  riftbreaker: { epic: 88 },
}

const text = (record, field) => {
  try {
    return String(record.get(field) || "").trim()
  } catch (_) {
    return ""
  }
}

migrate((app) => {
  const runCollection = app.findCollectionByNameOrId("gold_mine_event_runs")
  if (!runCollection.fields.getByName("remaining_seconds")) {
    runCollection.fields.add(new NumberField({
      name: "remaining_seconds",
      onlyInt: true,
      min: 0,
      max: 180,
      required: false,
    }))
  }
  const status = runCollection.fields.getByName("status")
  if (status && !status.values.includes("paused")) {
    status.values = [...status.values, "paused"]
  }
  app.save(runCollection)

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && is_active=true`,
    "",
    5000,
    0,
  )
  for (const template of templates) {
    const setKey = text(template, "set_key")
    const rarity = text(template, "rarity")
    const attack = weaponBalance[setKey]?.[rarity]
    if (
      attack !== undefined &&
      text(template, "set_piece_type") === "weapon"
    ) {
      template.set("base_attack", attack)
      app.save(template)
    }
  }

  const golems = app.findRecordsByFilter(
    "monsters",
    `monster_type="raid" && is_active=true`,
    "",
    10,
    0,
  )
  if (golems.length !== 1) {
    throw new Error(`active raid monster count=${golems.length}`)
  }
  golems[0].set("hp", 3400)
  golems[0].set("attack", 100)
  golems[0].set("defense", 40)
  app.save(golems[0])

  console.log("[balance-reapply] restored gold mine resume, equipment, and raid balance")
}, (app) => {
  // Preserve live balance and progress schema on rollback.
})
