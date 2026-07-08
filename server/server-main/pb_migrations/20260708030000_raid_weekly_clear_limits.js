migrate((app) => {
  try {
    app.findCollectionByNameOrId("raid_weekly_clears")
    return
  } catch (_) {}

  const users = app.findCollectionByNameOrId("users")
  const characters = app.findCollectionByNameOrId("characters")
  const raids = app.findCollectionByNameOrId("raids")
  const monsters = app.findCollectionByNameOrId("monsters")

  const collection = new Collection({
    id: "pbc_2070803000",
    type: "base",
    name: "raid_weekly_clears",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { name: "user", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "character", type: "relation", required: true, collectionId: characters.id, maxSelect: 1 },
      { name: "raid", type: "relation", required: true, collectionId: raids.id, maxSelect: 1 },
      { name: "monster", type: "relation", required: true, collectionId: monsters.id, maxSelect: 1 },
      { name: "week_start", type: "text", required: true, max: 10 },
      { name: "cleared_at", type: "date" },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_raid_weekly_clears_user_monster_week ON raid_weekly_clears (user, monster, week_start)",
      "CREATE INDEX idx_raid_weekly_clears_monster_week ON raid_weekly_clears (monster, week_start)",
    ],
  })

  app.save(collection)
}, (app) => {
  // Keep weekly clear history on rollback.
})
