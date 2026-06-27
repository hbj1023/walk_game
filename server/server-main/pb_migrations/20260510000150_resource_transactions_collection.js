migrate((app) => {
  try {
    app.findCollectionByNameOrId("resource_transactions")
    return
  } catch (_) {}

  const charactersCollection = app.findCollectionByNameOrId("characters")

  const collection = new Collection({
    id: "pbc_2091394083",
    type: "base",
    name: "resource_transactions",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    updateRule: "@request.auth.id != ''",
    deleteRule: null,
    fields: [
      { name: "character", type: "relation", required: true, collectionId: charactersCollection.id, maxSelect: 1 },
      { name: "resource_type", type: "text", max: 30 },
      { name: "transaction_type", type: "text", max: 30 },
      { name: "amount", type: "number", onlyInt: true },
      { name: "balance_after", type: "number", onlyInt: true },
      { name: "source_type", type: "text", max: 50 },
      { name: "source_id", type: "text", max: 100 },
      { name: "reason", type: "text", max: 255 },
    ],
    indexes: [
      "CREATE INDEX idx_resource_transactions_character ON resource_transactions (character)",
    ],
  })

  app.save(collection)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
