const cascadeRelations = [
  ["characters", "user", "users"],
  ["daily_step_summaries", "user", "users"],
  ["friendships", "user_low", "users"],
  ["friendships", "user_high", "users"],
  ["friendships", "requested_by_user", "users"],
  ["raid_invitations", "invited_user", "users"],
  ["raid_weekly_clears", "user", "users"],
  ["support_reports", "user", "users"],
  ["notifications", "user", "users"],
  ["user_missions", "user", "users"],
  ["gold_mine_event_runs", "user", "users"],

  ["character_stats", "character", "characters"],
  ["resource_transactions", "character", "characters"],
  ["stat_upgrade_logs", "character", "characters"],
  ["daily_shop_offers", "character", "characters"],
  ["owned_equipments", "character", "characters"],
  ["character_equipments", "character", "characters"],
  ["character_consumables", "character", "characters"],
  ["user_stage_progress", "character", "characters"],
  ["purchase_logs", "character", "characters"],
  ["reward_logs", "character", "characters"],
  ["battles", "character", "characters"],
  ["raids", "host_character", "characters"],
  ["raid_participants", "character", "characters"],
  ["raid_invitations", "inviter_character", "characters"],
  ["raid_weekly_clears", "character", "characters"],
  ["gold_mine_event_runs", "character", "characters"],

  ["character_equipments", "owned_equipment", "owned_equipments"],

  ["raid_progress", "raid", "raids"],
  ["raid_participants", "raid", "raids"],
  ["raid_invitations", "raid", "raids"],
  ["raid_weekly_clears", "raid", "raids"],
  ["battles", "raid", "raids"],
]

migrate((app) => {
  let updatedCount = 0

  for (const [collectionName, fieldName, targetName] of cascadeRelations) {
    const collection = app.findCollectionByNameOrId(collectionName)
    const target = app.findCollectionByNameOrId(targetName)
    const field = collection.fields.getByName(fieldName)

    if (!field) {
      throw new Error(`missing relation field ${collectionName}.${fieldName}`)
    }
    if (field.collectionId !== target.id) {
      throw new Error(
        `relation ${collectionName}.${fieldName} targets ${field.collectionId}, expected ${target.id}`,
      )
    }
    if (field.cascadeDelete === true) continue

    field.cascadeDelete = true
    app.save(collection)
    updatedCount++
  }

  const stepLogs = app.findCollectionByNameOrId("step_sync_logs")
  const deleteRule = "profile_id = @request.auth.id"
  if (stepLogs.deleteRule !== deleteRule) {
    stepLogs.deleteRule = deleteRule
    app.save(stepLogs)
  }

  console.log(
    `[account-delete-cascade] verified ${cascadeRelations.length} relations; updated ${updatedCount}`,
  )
}, (app) => {
  // Keep account deletion safe after rollback.
})
