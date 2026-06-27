migrate((app) => {
  try {
    app.findCollectionByNameOrId("daily_shop_offers")
    return
  } catch (_) {}

  const charactersCollection = app.findCollectionByNameOrId("characters")
  const shopsCollection = app.findCollectionByNameOrId("shops")
  const itemTemplatesCollection = app.findCollectionByNameOrId("item_templates")

  const collection = new Collection({
    id: "pbc_3859201120",
    type: "base",
    name: "daily_shop_offers",
    listRule: "character.user = @request.auth.id",
    viewRule: "character.user = @request.auth.id",
    createRule: "character.user = @request.auth.id",
    updateRule: "character.user = @request.auth.id",
    deleteRule: null,
    fields: [
      { name: "character", type: "relation", required: true, collectionId: charactersCollection.id, maxSelect: 1 },
      { name: "shop", type: "relation", required: true, collectionId: shopsCollection.id, maxSelect: 1 },
      { name: "item_template", type: "relation", required: true, collectionId: itemTemplatesCollection.id, maxSelect: 1 },
      { name: "offer_date", type: "text", required: true, max: 10 },
      { name: "slot_index", type: "number", required: true, onlyInt: true, min: 1 },
      { name: "original_price_coin", type: "number", required: true, onlyInt: true, min: 0 },
      { name: "price_coin", type: "number", required: true, onlyInt: true, min: 0 },
      { name: "discount_rate", type: "number", required: true, min: 0, max: 1 },
      { name: "reroll_count", type: "number", required: true, onlyInt: true, min: 0 },
      { name: "is_active", type: "bool" },
      { name: "is_purchased", type: "bool" },
      { name: "generated_at", type: "date" },
      { name: "purchased_at", type: "date" },
    ],
    indexes: [
      "CREATE INDEX idx_daily_shop_offers_character_date ON daily_shop_offers (character, offer_date)",
      "CREATE INDEX idx_daily_shop_offers_shop_date ON daily_shop_offers (shop, offer_date)",
    ],
  })

  app.save(collection)
}, (app) => {
  // Keep live offers on rollback.
})
