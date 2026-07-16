migrate((app) => {
  try {
    app.findCollectionByNameOrId("gold_mine_event_runs")
    return
  } catch (_) {}

  const users = app.findCollectionByNameOrId("users")
  const characters = app.findCollectionByNameOrId("characters")
  const collection = new Collection({
    id: "pbc_2071610000",
    type: "base",
    name: "gold_mine_event_runs",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: null,
    fields: [
      { name: "user", type: "relation", required: true, collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "character", type: "relation", required: true, collectionId: characters.id, maxSelect: 1, cascadeDelete: true },
      { name: "run_date", type: "text", required: true, max: 10 },
      { name: "status", type: "select", required: true, maxSelect: 1, values: ["running", "finished"] },
      { name: "started_at", type: "date", required: true },
      { name: "finished_at", type: "date", required: false },
      { name: "distance_m", type: "number", required: true, min: 0 },
      { name: "step_count", type: "number", required: true, onlyInt: true, min: 0 },
      { name: "max_speed_kmh", type: "number", required: true, min: 0 },
      { name: "reward_coin", type: "number", required: true, onlyInt: true, min: 0 },
      { name: "reward_stat_exp", type: "number", required: true, onlyInt: true, min: 0 },
      { name: "reward_ticket_fragments", type: "number", required: true, onlyInt: true, min: 0 },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_gold_mine_character_date ON gold_mine_event_runs (character, run_date)",
    ],
  })
  app.save(collection)
}, (app) => {
  try { app.delete(app.findCollectionByNameOrId("gold_mine_event_runs")) } catch (_) {}
})
