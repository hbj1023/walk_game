migrate((app) => {
  const records = app.findRecordsByFilter("characters", "level > 1", "", 500, 0)

  for (const character of records) {
    const level = Number(character.get("level") || 1)
    const current = Number(character.get("stat_exp") || 0)
    let minimum = 0

    for (let nextLevel = 2; nextLevel <= level; nextLevel++) {
      minimum += 40 + Math.floor((nextLevel - 1) / 5) * 10
    }

    if (current >= minimum) {
      continue
    }

    character.set("stat_exp", minimum)
    app.save(character)
  }
}, (app) => {
  // Keep earned stat points on rollback.
})
