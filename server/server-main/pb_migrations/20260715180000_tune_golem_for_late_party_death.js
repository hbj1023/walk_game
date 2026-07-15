migrate((app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=3000 && attack=81 && defense=40',
    "",
    10,
    0,
  )
  if (monsters.length !== 1) {
    throw new Error(`expected one set-focused golem raid monster, found ${monsters.length}`)
  }

  const golem = monsters[0]
  golem.set("hp", 2900)
  golem.set("attack", 85)
  app.save(golem)
}, (app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=2900 && attack=85 && defense=40',
    "",
    10,
    0,
  )
  for (const golem of monsters) {
    golem.set("hp", 3000)
    golem.set("attack", 81)
    app.save(golem)
  }
})
