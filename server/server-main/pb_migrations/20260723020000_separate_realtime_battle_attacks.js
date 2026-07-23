migrate((app) => {
  const battles = app.findCollectionByNameOrId("battles")

  try {
    battles.fields.getByName("realtime_attack_count_balance")
  } catch (_) {
    battles.fields.add(new NumberField({
      name: "realtime_attack_count_balance",
      onlyInt: true,
      min: 0,
    }))
  }

  try {
    battles.fields.getByName("realtime_attack_distance_remainder_m")
  } catch (_) {
    battles.fields.add(new NumberField({
      name: "realtime_attack_distance_remainder_m",
      onlyInt: false,
      min: 0,
    }))
  }

  app.save(battles)

  const characters = app.findRecordsByFilter("characters", 'id!=""', "", 5000, 0)
  for (const character of characters) {
    const storageLevel = Math.max(0, Math.min(5, Number(character.get("offline_storage_level") || 0)))
    const capacity = 10 + storageLevel * 5
    const currentBalance = Number(character.get("attack_count_balance") || 0)
    if (currentBalance > capacity) {
      character.set("attack_count_balance", capacity)
      app.save(character)
    }
  }
}, (app) => {
  const battles = app.findCollectionByNameOrId("battles")
  try {
    battles.fields.removeByName("realtime_attack_count_balance")
  } catch (_) {}
  try {
    battles.fields.removeByName("realtime_attack_distance_remainder_m")
  } catch (_) {}
  app.save(battles)
})
