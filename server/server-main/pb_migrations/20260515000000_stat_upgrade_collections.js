migrate((app) => {
  const charactersCollection = app.findCollectionByNameOrId("characters")

  let settings
  try {
    settings = app.findCollectionByNameOrId("stat_balance_settings")
  } catch (_) {
    settings = new Collection({
      id: "pbc_statbalset",
      type: "base",
      name: "stat_balance_settings",
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        { name: "stat_type", type: "text", required: true, max: 30 },
        { name: "base_cost", type: "number", required: true, onlyInt: true },
        { name: "square_divisor", type: "number", required: true },
        { name: "linear_multiplier", type: "number", required: true },
        { name: "formula_text", type: "text", max: 255 },
        { name: "is_active", type: "bool" },
      ],
      indexes: [
        "CREATE INDEX idx_stat_balance_settings_stat_type ON stat_balance_settings (stat_type)",
      ],
    })
    app.save(settings)
  }

  try {
    app.findCollectionByNameOrId("stat_upgrade_logs")
  } catch (_) {
    const logs = new Collection({
      id: "pbc_statlogs0",
      type: "base",
      name: "stat_upgrade_logs",
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: "@request.auth.id != ''",
      updateRule: null,
      deleteRule: null,
      fields: [
        { name: "character", type: "relation", required: true, collectionId: charactersCollection.id, maxSelect: 1 },
        { name: "stat_type", type: "text", required: true, max: 30 },
        { name: "before_value", type: "number", onlyInt: true },
        { name: "after_value", type: "number", onlyInt: true },
        { name: "cost_coin", type: "number", onlyInt: true },
        { name: "balance_after", type: "number", onlyInt: true },
        { name: "upgraded_at", type: "date" },
      ],
      indexes: [
        "CREATE INDEX idx_stat_upgrade_logs_character ON stat_upgrade_logs (character)",
      ],
    })
    app.save(logs)
  }

  const defaults = [
    { stat_type: "hp", base_cost: 100, square_divisor: 20, linear_multiplier: 2, formula_text: "base_cost + (currentStat * currentStat) / square_divisor + (currentStat * linear_multiplier)", is_active: true },
    { stat_type: "attack", base_cost: 100, square_divisor: 20, linear_multiplier: 2, formula_text: "base_cost + (currentStat * currentStat) / square_divisor + (currentStat * linear_multiplier)", is_active: true },
    { stat_type: "defense", base_cost: 100, square_divisor: 20, linear_multiplier: 2, formula_text: "base_cost + (currentStat * currentStat) / square_divisor + (currentStat * linear_multiplier)", is_active: true },
    { stat_type: "agility", base_cost: 100, square_divisor: 20, linear_multiplier: 2, formula_text: "base_cost + (currentStat * currentStat) / square_divisor + (currentStat * linear_multiplier)", is_active: true },
  ]

  for (const item of defaults) {
    const existing = app.findRecordsByFilter("stat_balance_settings", `stat_type="${item.stat_type}"`, "", 1, 0)
    if (existing.length > 0) continue
    const record = new Record(settings)
    for (const [key, value] of Object.entries(item)) {
      record.set(key, value)
    }
    app.save(record)
  }
}, (app) => {
  // Keep data on rollback.
})
