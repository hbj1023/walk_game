migrate((app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && name="골렘" && is_active=true',
    "",
    10,
    0,
  )
  if (monsters.length !== 1) {
    throw new Error(`expected one active golem raid monster, found ${monsters.length}`)
  }

  const golem = monsters[0]
  golem.set("hp", 2900)
  golem.set("attack", 100)
  golem.set("defense", 40)
  app.save(golem)
}, (app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && name="골렘" && is_active=true',
    "",
    10,
    0,
  )
  for (const golem of monsters) {
    golem.set("hp", 2900)
    golem.set("attack", 85)
    golem.set("defense", 40)
    app.save(golem)
  }
})
