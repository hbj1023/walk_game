migrate((app) => {
  try {
    app.findCollectionByNameOrId("characters")
    return
  } catch (_) {}

  const collection = new Collection({
    id: "pbc_3298390430",
    type: "base",
    name: "characters",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    updateRule: "@request.auth.id != ''",
    deleteRule: null,
    fields: [
      { name: "user", type: "relation", required: true, collectionId: "_pb_users_auth_", maxSelect: 1 },
      { name: "name", type: "text", max: 100 },
      { name: "gender", type: "text", max: 20 },
      { name: "level", type: "number", onlyInt: true },
      { name: "exp", type: "number", onlyInt: true },
      { name: "current_hp", type: "number", onlyInt: true },
      { name: "coin_balance", type: "number", onlyInt: true },
      { name: "attack_count_balance", type: "number", onlyInt: true },
      { name: "hair_type", type: "text", max: 50 },
      { name: "hair_color", type: "text", max: 50 },
      { name: "skin_color", type: "text", max: 50 },
      { name: "outfit_type", type: "text", max: 50 },
      { name: "accessory_type", type: "text", max: 50 },
    ],
    indexes: [
      "CREATE INDEX idx_characters_user ON characters (user)",
    ],
  })

  app.save(collection)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
