// migration-policy: schema-drift-repair-reviewed
migrate((app) => {
  try {
    app.db().newQuery("ALTER TABLE item_templates ADD COLUMN catalog_key TEXT NOT NULL DEFAULT ''").execute()
    console.log("[catalog-key] repaired missing item_templates.catalog_key column")
  } catch (error) {
    if (!String(error).toLowerCase().includes("duplicate column")) throw error
    console.log("[catalog-key] item_templates.catalog_key column already exists")
  }
}, (app) => {
  // Keep the physical column aligned with the PocketBase collection schema.
})
