migrate((app) => {
  const collection = app.findCollectionByNameOrId("raid_weekly_clears")

  collection.createRule = [
    "@request.auth.id != ''",
    "character.user = user",
    "raid.raid_participants_via_raid.character.user ?= @request.auth.id",
  ].join(" && ")

  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("raid_weekly_clears")
  collection.createRule = [
    "@request.auth.id != ''",
    "character.user = user",
    "raid.host_character.user = @request.auth.id",
  ].join(" && ")
  app.save(collection)
})
