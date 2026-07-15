migrate((app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=3400 && attack=80 && defense=24',
    "",
    10,
    0,
  )
  if (monsters.length !== 1) {
    throw new Error(`expected one balanced golem raid monster, found ${monsters.length}`)
  }

  const golem = monsters[0]
  golem.set("hp", 3000)
  golem.set("attack", 86)
  golem.set("defense", 30)
  app.save(golem)
}, (app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=3000 && attack=86 && defense=30',
    "",
    10,
    0,
  )
  for (const golem of monsters) {
    golem.set("hp", 3400)
    golem.set("attack", 80)
    golem.set("defense", 24)
    app.save(golem)
  }
})
