migrate((app) => {
  let profileEmotes
  try {
    profileEmotes = app.findCollectionByNameOrId("profile_emotes")
  } catch (_) {
    profileEmotes = new Collection({
      id: "pbc_3053003000",
      type: "base",
      name: "profile_emotes",
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        { name: "name", type: "text", required: true, max: 80 },
        { name: "asset_key", type: "text", required: true, max: 80 },
        { name: "image_url", type: "text", max: 255 },
        { name: "category", type: "text", max: 40 },
        { name: "sort_order", type: "number", onlyInt: true, min: 0 },
        { name: "is_active", type: "bool" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_profile_emotes_asset_key ON profile_emotes (asset_key)",
      ],
    })
    app.save(profileEmotes)
  }

  const users = app.findCollectionByNameOrId("users")
  try {
    users.fields.getByName("profile_emote")
  } catch (_) {
    users.fields.add(new RelationField({
      name: "profile_emote",
      collectionId: profileEmotes.id,
      cascadeDelete: false,
      maxSelect: 1,
    }))
    app.save(users)
  }
  try {
    users.fields.getByName("profile_image_source")
  } catch (_) {
    users.fields.add(new TextField({
      name: "profile_image_source",
      max: 20,
    }))
    app.save(users)
  }

  const upsertByAssetKey = (values) => {
    const existing = app.findRecordsByFilter("profile_emotes", `asset_key="${values.asset_key}"`, "", 1, 0)
    const record = existing.length > 0 ? existing[0] : new Record(profileEmotes)
    for (const [key, value] of Object.entries(values)) {
      record.set(key, value)
    }
    app.save(record)
  }

  const defaults = [
    { name: "Happy", asset_key: "emote_happy", image_url: "assets/images/profile/emote_happy.png", category: "default", sort_order: 10, is_active: true },
    { name: "Smile", asset_key: "emote_smile", image_url: "assets/images/profile/emote_smile.png", category: "default", sort_order: 20, is_active: true },
    { name: "Cool", asset_key: "emote_cool", image_url: "assets/images/profile/emote_cool.png", category: "default", sort_order: 30, is_active: true },
    { name: "Angry", asset_key: "emote_angry", image_url: "assets/images/profile/emote_angry.png", category: "default", sort_order: 40, is_active: true },
    { name: "Sleepy", asset_key: "emote_sleepy", image_url: "assets/images/profile/emote_sleepy.png", category: "default", sort_order: 50, is_active: true },
    { name: "Surprise", asset_key: "emote_surprise", image_url: "assets/images/profile/emote_surprise.png", category: "default", sort_order: 60, is_active: true },
  ]
  for (const item of defaults) {
    upsertByAssetKey(item)
  }
}, (app) => {
  // Keep profile data on rollback.
})
