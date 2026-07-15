migrate((app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=3000 && attack=86 && defense=30',
    "",
    10,
    0,
  )
  if (monsters.length !== 1) {
    throw new Error(`expected one hardened golem raid monster, found ${monsters.length}`)
  }

  const golem = monsters[0]
  golem.set("attack", 81)
  golem.set("defense", 40)
  app.save(golem)
}, (app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=3000 && attack=81 && defense=40',
    "",
    10,
    0,
  )
  for (const golem of monsters) {
    golem.set("attack", 86)
    golem.set("defense", 30)
    app.save(golem)
  }
})
