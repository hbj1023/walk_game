migrate((app) => {
  try {
    app.findCollectionByNameOrId("step_sync_logs")
    return
  } catch (_) {}

  const collection = new Collection({
    id: "pbc_1485792847",
    type: "base",
    name: "step_sync_logs",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    updateRule: "@request.auth.id != ''",
    deleteRule: null,
    fields: [
      { name: "profile_id", type: "text", required: true },
      { name: "source_type", type: "text", max: 20 },
      { name: "sync_type", type: "text", max: 20 },
      { name: "step_count", type: "number", onlyInt: true },
      { name: "distance_m", type: "number", onlyInt: true },
      { name: "captured_at", type: "date" },
      { name: "abnormal_flag", type: "bool" },
      { name: "abnormal_reason", type: "text", max: 255 },
    ],
    indexes: [
      "CREATE INDEX idx_step_sync_logs_profile_id ON step_sync_logs (profile_id)",
    ],
  })

  app.save(collection)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
