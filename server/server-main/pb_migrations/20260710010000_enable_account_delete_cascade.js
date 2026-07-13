migrate((app) => {
  const setCascadeDelete = (collectionName, fieldName) => {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      const field = collection.fields.find((item) => item.name === fieldName)
      if (!field || field.type !== "relation") {
        console.log(`[account-delete-cascade] skipped ${collectionName}.${fieldName}`)
        return
      }
      if (field.cascadeDelete === true) return

      field.cascadeDelete = true
      app.save(collection)
      console.log(`[account-delete-cascade] enabled ${collectionName}.${fieldName}`)
    } catch (err) {
      console.log(`[account-delete-cascade] skipped ${collectionName}.${fieldName}: ${err}`)
    }
  }

  const setDeleteRule = (collectionName, deleteRule) => {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      if (collection.deleteRule === deleteRule) return

      collection.deleteRule = deleteRule
      app.save(collection)
      console.log(`[account-delete-cascade] set delete rule for ${collectionName}`)
    } catch (err) {
      console.log(`[account-delete-cascade] skipped delete rule for ${collectionName}: ${err}`)
    }
  }

  const userRelations = [
    ["characters", "user"],
    ["daily_step_summaries", "user"],
    ["friendships", "user_low"],
    ["friendships", "user_high"],
    ["friendships", "requested_by_user"],
    ["raid_invitations", "invited_user"],
    ["raid_weekly_clears", "user"],
    ["support_reports", "user"],
    ["notifications", "user"],
    ["user_missions", "user"],
  ]

  const characterRelations = [
    ["character_stats", "character"],
    ["resource_transactions", "character"],
    ["stat_upgrade_logs", "character"],
    ["daily_shop_offers", "character"],
    ["owned_equipments", "character"],
    ["character_equipments", "character"],
    ["character_equipments", "owned_equipment"],
    ["character_consumables", "character"],
    ["user_stage_progress", "character"],
    ["purchase_logs", "character"],
    ["reward_logs", "character"],
    ["battles", "character"],
    ["raids", "host_character"],
    ["raid_participants", "character"],
    ["raid_invitations", "inviter_character"],
    ["raid_weekly_clears", "character"],
  ]

  const raidRelations = [
    ["raid_progress", "raid"],
    ["raid_participants", "raid"],
    ["raid_invitations", "raid"],
    ["raid_weekly_clears", "raid"],
    ["battles", "raid"],
  ]

  for (const [collectionName, fieldName] of [
    ...userRelations,
    ...characterRelations,
    ...raidRelations,
  ]) {
    setCascadeDelete(collectionName, fieldName)
  }

  setDeleteRule("step_sync_logs", "profile_id = @request.auth.id")
}, (app) => {
  // Keep cascade-delete protection enabled after rollback.
})
