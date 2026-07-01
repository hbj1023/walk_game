migrate((app) => {
  const records = app.findRecordsByFilter("characters", "level > 1", "", 500, 0)

  for (const character of records) {
    const level = Number(character.get("level") || 1)
    const current = Number(character.get("stat_exp") || 0)
    const minimum = Math.max(0, level - 1) * 10
    if (current >= minimum) {
      continue
    }
    character.set("stat_exp", minimum)
    app.save(character)
  }
}, (app) => {
  // Keep earned stat points on rollback.
})
