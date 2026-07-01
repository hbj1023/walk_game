migrate((app) => {
  const updates = [
    { stageNo: 3, stageType: "normal", monsterType: "normal", hp: 145, attack: 13, defense: 2, agility: 6 },
    { stageNo: 4, stageType: "normal", monsterType: "normal", hp: 185, attack: 16, defense: 3, agility: 7 },
    { stageNo: 5, stageType: "boss", monsterType: "boss", hp: 320, attack: 23, defense: 5, agility: 5 },
  ]

  for (const update of updates) {
    const stages = app.findRecordsByFilter(
      "stages",
      `stage_no=${update.stageNo} && stage_type="${update.stageType}" && is_active=true`,
      "",
      1,
      0,
    )
    if (stages.length === 0) continue

    const stageMonsters = app.findRecordsByFilter(
      "stage_monsters",
      `stage="${stages[0].id}" && spawn_order=1`,
      "",
      1,
      0,
    )
    if (stageMonsters.length === 0) continue

    const monster = app.findRecordById("monsters", stageMonsters[0].get("monster"))
    if (!monster || monster.get("monster_type") !== update.monsterType) continue

    monster.set("hp", update.hp)
    monster.set("attack", update.attack)
    monster.set("defense", update.defense)
    monster.set("agility", update.agility)
    app.save(monster)
  }
}, (app) => {
  const updates = [
    { stageNo: 3, stageType: "normal", monsterType: "normal", hp: 160, attack: 15, defense: 3, agility: 6 },
    { stageNo: 4, stageType: "normal", monsterType: "normal", hp: 210, attack: 18, defense: 4, agility: 7 },
    { stageNo: 5, stageType: "boss", monsterType: "boss", hp: 380, attack: 28, defense: 7, agility: 5 },
  ]

  for (const update of updates) {
    const stages = app.findRecordsByFilter(
      "stages",
      `stage_no=${update.stageNo} && stage_type="${update.stageType}" && is_active=true`,
      "",
      1,
      0,
    )
    if (stages.length === 0) continue

    const stageMonsters = app.findRecordsByFilter(
      "stage_monsters",
      `stage="${stages[0].id}" && spawn_order=1`,
      "",
      1,
      0,
    )
    if (stageMonsters.length === 0) continue

    const monster = app.findRecordById("monsters", stageMonsters[0].get("monster"))
    if (!monster || monster.get("monster_type") !== update.monsterType) continue

    monster.set("hp", update.hp)
    monster.set("attack", update.attack)
    monster.set("defense", update.defense)
    monster.set("agility", update.agility)
    app.save(monster)
  }
})
