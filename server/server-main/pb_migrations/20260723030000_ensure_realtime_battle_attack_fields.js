const ensureNumberField = (collection, name, onlyInt) => {
  let existing = null
  try {
    existing = collection.fields.getByName(name)
  } catch (_) {
    existing = null
  }
  if (existing) return

  collection.fields.add(new NumberField({
    name,
    onlyInt,
    min: 0,
  }))
}

migrate((app) => {
  const battles = app.findCollectionByNameOrId("battles")
  ensureNumberField(battles, "realtime_attack_count_balance", true)
  ensureNumberField(battles, "realtime_attack_distance_remainder_m", false)
  app.save(battles)
}, (app) => {
  const battles = app.findCollectionByNameOrId("battles")
  let realtimeBalanceField = null
  let realtimeRemainderField = null
  try {
    realtimeBalanceField = battles.fields.getByName("realtime_attack_count_balance")
  } catch (_) {
    realtimeBalanceField = null
  }
  try {
    realtimeRemainderField = battles.fields.getByName("realtime_attack_distance_remainder_m")
  } catch (_) {
    realtimeRemainderField = null
  }
  if (realtimeBalanceField) {
    battles.fields.removeByName("realtime_attack_count_balance")
  }
  if (realtimeRemainderField) {
    battles.fields.removeByName("realtime_attack_distance_remainder_m")
  }
  app.save(battles)
})
