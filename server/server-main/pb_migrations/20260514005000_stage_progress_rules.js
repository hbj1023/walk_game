migrate((app) => {
  const collection = app.findCollectionByNameOrId("user_stage_progress")
  const ownCharacter = "character.user = @request.auth.id"

  collection.listRule = ownCharacter
  collection.viewRule = ownCharacter
  collection.createRule = ownCharacter
  collection.updateRule = ownCharacter

  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("user_stage_progress")

  collection.listRule = null
  collection.viewRule = null
  collection.createRule = null
  collection.updateRule = null

  app.save(collection)
})
