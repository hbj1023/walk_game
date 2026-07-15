migrate((app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=4000 && attack=80 && defense=24',
    "",
    10,
    0,
  )
  if (monsters.length !== 1) {
    throw new Error(`expected one active golem raid monster, found ${monsters.length}`)
  }

  const golem = monsters[0]
  golem.set("hp", 3400)
  app.save(golem)
}, (app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    'monster_type="raid" && hp=3400 && attack=80 && defense=24',
    "",
    10,
    0,
  )
  for (const golem of monsters) {
    golem.set("hp", 4000)
    app.save(golem)
  }
})
