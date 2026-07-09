migrate((app) => {
  try {
    app.findCollectionByNameOrId("support_reports")
    return
  } catch (_) {}

  const users = app.findCollectionByNameOrId("users")

  const collection = new Collection({
    id: "pbc_2070905000",
    type: "base",
    name: "support_reports",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "user = @request.auth.id",
    updateRule: null,
    deleteRule: null,
    fields: [
      { name: "user", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "email", type: "text", required: false, max: 120 },
      { name: "screen", type: "text", required: false, max: 80 },
      { name: "message", type: "text", required: true, max: 1000 },
      { name: "status", type: "select", required: true, maxSelect: 1, values: ["open", "reviewing", "resolved"] },
      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE INDEX idx_support_reports_user_created ON support_reports (user, created)",
      "CREATE INDEX idx_support_reports_status_created ON support_reports (status, created)",
    ],
  })

  app.save(collection)
}, (app) => {
  try {
    const collection = app.findCollectionByNameOrId("support_reports")
    app.delete(collection)
  } catch (_) {}
})
