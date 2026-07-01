migrate((app) => {
  const stages = app.findRecordsByFilter(
    "stages",
    `stage_no=5 && stage_type="boss" && is_active=true`,
    "",
    1,
    0,
  )
  if (stages.length === 0) {
    return
  }

  const links = app.findRecordsByFilter(
    "stage_monsters",
    `stage="${stages[0].id}"`,
    "spawn_order",
    1,
    0,
  )
  if (links.length === 0) {
    return
  }

  const monsterID = links[0].get("monster")
  if (!monsterID) {
    return
  }

  const monster = app.findRecordById("monsters", monsterID)
  if (monster.get("monster_type") !== "boss") {
    return
  }

  monster.set("hp", 520)
  monster.set("attack", 38)
  monster.set("defense", 10)
  monster.set("agility", 5)
  app.save(monster)
}, (app) => {
  // Keep live boss battle stats on rollback.
})
