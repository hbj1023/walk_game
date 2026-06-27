migrate((app) => {
  const renameFirstStageMonster = (stageNo, stageType, name) => {
    const stages = app.findRecordsByFilter(
      "stages",
      `stage_no=${stageNo} && stage_type="${stageType}" && is_active=true`,
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
    monster.set("name", name)
    app.save(monster)
  }

  renameFirstStageMonster(4, "normal", "블루 고블린")
  renameFirstStageMonster(5, "boss", "퍼플 고블린")
}, (app) => {
  // Keep live monster names on rollback.
})
