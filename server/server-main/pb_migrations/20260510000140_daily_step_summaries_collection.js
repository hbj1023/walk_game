migrate((app) => {
  try {
    app.findCollectionByNameOrId("daily_step_summaries")
    return
  } catch (_) {}

  const collection = new Collection({
    id: "pbc_2495089913",
    type: "base",
    name: "daily_step_summaries",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    updateRule: "@request.auth.id != ''",
    deleteRule: null,
    fields: [
      { name: "user", type: "relation", required: true, collectionId: "_pb_users_auth_", maxSelect: 1 },
      { name: "record_date", type: "date", required: true },
      { name: "total_step_count", type: "number", onlyInt: true },
      { name: "total_distance_m", type: "number", onlyInt: true },
      { name: "attack_count_earned", type: "number", onlyInt: true },
      { name: "attack_distance_remainder_m", type: "number" },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_daily_step_summaries_user_date ON daily_step_summaries (user, record_date)",
    ],
  })

  app.save(collection)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
