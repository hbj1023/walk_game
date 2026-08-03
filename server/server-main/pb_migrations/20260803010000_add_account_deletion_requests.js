migrate((app) => {
  try {
    app.findCollectionByNameOrId("account_deletion_requests")
    return
  } catch (_) {}

  const collection = new Collection({
    id: "pbc_2080301000",
    type: "base",
    name: "account_deletion_requests",
    listRule: null,
    viewRule: null,
    createRule: "",
    updateRule: null,
    deleteRule: null,
    fields: [
      { name: "email", type: "email", required: true },
      { name: "reason", type: "text", required: false, max: 1000 },
      { name: "status", type: "select", required: true, maxSelect: 1, values: ["pending", "reviewing", "completed", "rejected"] },
      { name: "source", type: "select", required: true, maxSelect: 1, values: ["web"] },
      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE INDEX idx_account_deletion_requests_status_created ON account_deletion_requests (status, created)",
      "CREATE INDEX idx_account_deletion_requests_email_created ON account_deletion_requests (email, created)",
    ],
  })

  app.save(collection)
}, (app) => {
  try {
    const collection = app.findCollectionByNameOrId("account_deletion_requests")
    app.delete(collection)
  } catch (_) {}
})
