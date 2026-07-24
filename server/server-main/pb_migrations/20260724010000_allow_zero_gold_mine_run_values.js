migrate((app) => {
  const collection = app.findCollectionByNameOrId("gold_mine_event_runs")
  const zeroValueFields = [
    "distance_m",
    "step_count",
    "max_speed_kmh",
    "reward_coin",
    "reward_stat_exp",
    "reward_ticket_fragments",
  ]

  for (const fieldName of zeroValueFields) {
    const field = collection.fields.getByName(fieldName)
    if (field) {
      field.required = false
    }
  }

  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("gold_mine_event_runs")
  const zeroValueFields = [
    "distance_m",
    "step_count",
    "max_speed_kmh",
    "reward_coin",
    "reward_stat_exp",
    "reward_ticket_fragments",
  ]

  for (const fieldName of zeroValueFields) {
    const field = collection.fields.getByName(fieldName)
    if (field) {
      field.required = true
    }
  }

  app.save(collection)
})
