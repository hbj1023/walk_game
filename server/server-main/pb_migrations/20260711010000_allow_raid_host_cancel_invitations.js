migrate((app) => {
  const collection = app.findCollectionByNameOrId("raid_invitations")
  const canSeeInvitation = [
    "invited_user = @request.auth.id",
    "inviter_character.user = @request.auth.id",
  ].join(" || ")
  const canCreateInvitation = "inviter_character.user = @request.auth.id"
  const canUpdateInvitation = [
    "invited_user = @request.auth.id",
    "inviter_character.user = @request.auth.id",
    "raid.host_character.user = @request.auth.id",
  ].join(" || ")

  collection.listRule = canSeeInvitation
  collection.viewRule = canSeeInvitation
  collection.createRule = canCreateInvitation
  collection.updateRule = canUpdateInvitation
  app.save(collection)
}, (app) => {
  try {
    const collection = app.findCollectionByNameOrId("raid_invitations")
    const canSeeInvitation = [
      "invited_user = @request.auth.id",
      "inviter_character.user = @request.auth.id",
    ].join(" || ")

    collection.listRule = canSeeInvitation
    collection.viewRule = canSeeInvitation
    collection.createRule = "inviter_character.user = @request.auth.id"
    collection.updateRule = "invited_user = @request.auth.id"
    app.save(collection)
  } catch (_) {}
})
