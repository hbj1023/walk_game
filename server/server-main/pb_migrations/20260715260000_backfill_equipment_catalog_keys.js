const canonicalCatalogKeys = [
  ["chapter1.epic.adventurer.weapon", "\ubaa8\ud5d8\uac00\uc758 \uac80", "weapon"],
  ["chapter1.epic.adventurer.helmet", "\ubaa8\ud5d8\uac00\uc758 \ud22c\uad6c", "helmet"],
  ["chapter1.epic.adventurer.armor", "\ubaa8\ud5d8\uac00\uc758 \uac11\uc637", "armor"],
  ["chapter1.epic.adventurer.shoes", "\ubaa8\ud5d8\uac00\uc758 \uc2e0\ubc1c", "shoes"],
  ["chapter2.epic.poison_assassin.weapon", "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \ub2e8\uac80", "weapon"],
  ["chapter2.epic.poison_assassin.helmet", "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \ubcf5\uba74", "helmet"],
  ["chapter2.epic.poison_assassin.armor", "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uac11\uc637", "armor"],
  ["chapter2.epic.poison_assassin.shoes", "\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uc7a5\ud654", "shoes"],
]

migrate((app) => {
  const collection = app.findCollectionByNameOrId("item_templates")
  collection.fields.getByName("catalog_key")

  for (const [catalogKey, name, pieceType] of canonicalCatalogKeys) {
    const records = app.findRecordsByFilter("item_templates", `name="${name}" && rarity="epic" && is_active=true`, "", 10, 0)
    if (records.length === 0) throw new Error(`missing active canonical item ${name}`)
    const matching = records.filter((record) => String(record.get("set_piece_type") || "") === pieceType)
    if (matching.length === 0) throw new Error(`canonical piece mismatch for ${name}`)
    const ranked = matching.map((record) => {
      const shopRefs = app.findRecordsByFilter("shop_items", `item_template="${record.id}" && is_active=true`, "", 1, 0).length
      const ownedRefs = app.findRecordsByFilter("owned_equipments", `item_template="${record.id}"`, "", 1, 0).length
      return { record, score: shopRefs * 2 + ownedRefs }
    }).sort((left, right) => right.score - left.score || String(left.record.id).localeCompare(String(right.record.id)))
    if (matching.length > 1) {
      console.warn(`[catalog-key] ${name}: ${matching.length} active duplicates; selected ${ranked[0].record.id}`)
    }
    const template = ranked[0].record
    template.set("catalog_key", catalogKey)
    app.save(template)
  }

  app.db().newQuery("CREATE UNIQUE INDEX IF NOT EXISTS idx_item_templates_catalog_key ON item_templates (catalog_key) WHERE catalog_key != ''").execute()
}, (app) => {
  // Keep immutable catalog identities on rollback.
})
