const chapter3CounterattackPressure = [
  { stageNo: 11, stageType: "normal", monsterType: "normal", attack: 88 },
  { stageNo: 12, stageType: "normal", monsterType: "normal", attack: 100 },
  { stageNo: 13, stageType: "normal", monsterType: "normal", attack: 114 },
  { stageNo: 14, stageType: "normal", monsterType: "normal", attack: 130 },
  { stageNo: 15, stageType: "boss", monsterType: "boss", attack: 150 },
]

migrate((app) => {
  for (const balance of chapter3CounterattackPressure) {
    const stages = app.findRecordsByFilter(
      "stages",
      `stage_no=${balance.stageNo} && stage_type="${balance.stageType}" && is_active=true`,
      "",
      10,
      0,
    )
    if (stages.length === 0) throw new Error(`active chapter 3 stage ${balance.stageNo} not found`)

    let updated = 0
    for (const stage of stages) {
      const links = app.findRecordsByFilter("stage_monsters", `stage="${stage.id}" && spawn_order=1`, "", 10, 0)
      for (const link of links) {
        const monster = app.findRecordById("monsters", link.get("monster"))
        if (String(monster.get("monster_type") || "") !== balance.monsterType) continue
        monster.set("attack", balance.attack)
        app.save(monster)
        updated++
      }
    }
    if (updated === 0) throw new Error(`chapter 3 stage ${balance.stageNo} monster attack was not updated`)
  }

  console.log("[chapter3-pressure] raised attacks to 88/100/114/130/150 so chapter 2 rare armor cannot trivialize quarry counterattacks")
}, (app) => {
  // Keep chapter 3 counterattack pressure on rollback.
})
