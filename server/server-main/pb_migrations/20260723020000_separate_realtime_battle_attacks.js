migrate((app) => {
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
}, (_) => {
  return null
})
