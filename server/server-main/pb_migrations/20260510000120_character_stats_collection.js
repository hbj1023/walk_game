migrate((app) => {
  try {
    app.findCollectionByNameOrId("character_stats")
    return
  } catch (_) {}

  const charactersCollection = app.findCollectionByNameOrId("characters")

  const collection = new Collection({
    id: "pbc_3351801178",
    type: "base",
    name: "character_stats",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    updateRule: "@request.auth.id != ''",
    deleteRule: null,
    fields: [
      { name: "character", type: "relation", required: true, collectionId: charactersCollection.id, maxSelect: 1 },
      { name: "base_hp", type: "number", onlyInt: true },
      { name: "base_attack", type: "number", onlyInt: true },
      { name: "base_defense", type: "number", onlyInt: true },
      { name: "base_agility", type: "number", onlyInt: true },
      { name: "upgraded_hp", type: "number", onlyInt: true },
      { name: "upgraded_attack", type: "number", onlyInt: true },
      { name: "upgraded_defense", type: "number", onlyInt: true },
      { name: "upgraded_agility", type: "number", onlyInt: true },
    ],
    indexes: [
      "CREATE INDEX idx_character_stats_character ON character_stats (character)",
    ],
  })

  app.save(collection)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
