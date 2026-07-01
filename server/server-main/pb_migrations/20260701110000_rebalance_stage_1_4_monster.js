migrate((app) => {
  const stage = app.findFirstRecordByFilter("stages", `stage_no=4 && stage_type="normal"`)
  if (!stage) return

  const stageMonster = app.findFirstRecordByFilter(
    "stage_monsters",
    `stage="${stage.id}" && spawn_order=1`,
  )
  if (!stageMonster) return

  const monster = app.findRecordById("monsters", stageMonster.get("monster"))
  if (!monster) return

  monster.set("hp", 210)
  monster.set("attack", 18)
  monster.set("defense", 4)
  monster.set("agility", 7)
  app.save(monster)
}, (app) => {
  const stage = app.findFirstRecordByFilter("stages", `stage_no=4 && stage_type="normal"`)
  if (!stage) return

  const stageMonster = app.findFirstRecordByFilter(
    "stage_monsters",
    `stage="${stage.id}" && spawn_order=1`,
  )
  if (!stageMonster) return

  const monster = app.findRecordById("monsters", stageMonster.get("monster"))
  if (!monster) return

  monster.set("hp", 260)
  monster.set("attack", 22)
  monster.set("defense", 6)
  monster.set("agility", 7)
  app.save(monster)
})
