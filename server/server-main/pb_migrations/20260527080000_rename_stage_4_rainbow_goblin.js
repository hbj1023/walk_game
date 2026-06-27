migrate((app) => {
  const stages = app.findRecordsByFilter(
    "stages",
    `stage_no=4 && stage_type="normal" && is_active=true`,
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
  monster.set("name", "레인보우 고블린")
  app.save(monster)
}, (app) => {
  // Keep live monster names on rollback.
})
