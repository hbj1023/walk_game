migrate((app) => {
  const collection = app.findCollectionByNameOrId("item_templates")
  if (!collection.fields.getByName("set_key")) {
    app.db().newQuery(`
      CREATE TABLE IF NOT EXISTS _item_template_set_key_backup (
        id TEXT PRIMARY KEY,
        set_key TEXT NOT NULL DEFAULT ''
      )
    `).execute()
    try {
      app.db().newQuery(`
        INSERT OR REPLACE INTO _item_template_set_key_backup (id, set_key)
        SELECT id, COALESCE(set_key, '') FROM item_templates
      `).execute()
      app.db().newQuery("ALTER TABLE item_templates DROP COLUMN set_key").execute()
    } catch (error) {
      if (!String(error).toLowerCase().includes("no such column")) throw error
    }

    collection.fields.add(new TextField({ name: "set_key", max: 80 }))
    app.save(collection)

    app.db().newQuery(`
      UPDATE item_templates
      SET set_key = COALESCE((
        SELECT backup.set_key
        FROM _item_template_set_key_backup backup
        WHERE backup.id = item_templates.id
      ), '')
    `).execute()
    app.db().newQuery("DROP TABLE _item_template_set_key_backup").execute()
  }

  const setKeys = {
    "\uac80\uc0ac": "quarry_swordsman",
    "\uad11\uc804\uc0ac": "quarry_berserker",
    "\ucc3d\uc220\uc0ac": "quarry_spearmaster",
    "\ub3c4\uc801": "quarry_rogue",
    "\uae30\uc0ac": "quarry_knight",
  }
  const templates = app.findRecordsByFilter("item_templates", "", "", 5000, 0)
  for (const template of templates) {
    const name = String(template.get("name") || "")
    if (!name.includes("\ucc44\uc11d\ub2e8")) continue

    for (const [role, setKey] of Object.entries(setKeys)) {
      if (!name.includes(role)) continue
      const slot = String(template.get("equipment_slot") || "")
      const piece = slot === "sword" ? "weapon" : slot
      if (!["weapon", "helmet", "armor", "shoes"].includes(piece)) break
      template.set("set_key", setKey)
      template.set("set_piece_type", piece)
      app.save(template)
      break
    }
  }
}, (app) => {
  // Keep repaired live schema and equipment metadata on rollback.
})
