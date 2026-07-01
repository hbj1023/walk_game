migrate((app) => {
  const updates = [
    { stageNo: 1, stageType: "normal", monsterType: "normal", hp: 75, attack: 8, defense: 1, agility: 4 },
    { stageNo: 2, stageType: "normal", monsterType: "normal", hp: 115, attack: 11, defense: 2, agility: 5 },
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
    const stage = stages[0]
    if (!stage) continue

    const stageMonsters = app.findRecordsByFilter(
      "stage_monsters",
      `stage="${stage.id}" && spawn_order=1`,
      "",
      1,
      0,
    )
    if (stageMonsters.length === 0) continue
    const stageMonster = stageMonsters[0]
    if (!stageMonster) continue

    const monster = app.findRecordById("monsters", stageMonster.get("monster"))
    if (!monster || monster.get("monster_type") !== update.monsterType) continue

    monster.set("hp", update.hp)
    monster.set("attack", update.attack)
    monster.set("defense", update.defense)
    monster.set("agility", update.agility)
    app.save(monster)
  }
}, (app) => {
  const updates = [
    { stageNo: 1, stageType: "normal", monsterType: "normal", hp: 90, attack: 10, defense: 1, agility: 4 },
    { stageNo: 2, stageType: "normal", monsterType: "normal", hp: 130, attack: 13, defense: 2, agility: 5 },
    { stageNo: 3, stageType: "normal", monsterType: "normal", hp: 190, attack: 17, defense: 4, agility: 6 },
    { stageNo: 4, stageType: "normal", monsterType: "normal", hp: 210, attack: 18, defense: 4, agility: 7 },
    { stageNo: 5, stageType: "boss", monsterType: "boss", hp: 520, attack: 38, defense: 10, agility: 5 },
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
    const stage = stages[0]
    if (!stage) continue

    const stageMonsters = app.findRecordsByFilter(
      "stage_monsters",
      `stage="${stage.id}" && spawn_order=1`,
      "",
      1,
      0,
    )
    if (stageMonsters.length === 0) continue
    const stageMonster = stageMonsters[0]
    if (!stageMonster) continue

    const monster = app.findRecordById("monsters", stageMonster.get("monster"))
    if (!monster || monster.get("monster_type") !== update.monsterType) continue

    monster.set("hp", update.hp)
    monster.set("attack", update.attack)
    monster.set("defense", update.defense)
    monster.set("agility", update.agility)
    app.save(monster)
  }
})
