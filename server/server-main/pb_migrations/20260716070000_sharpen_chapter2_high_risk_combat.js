const chapter2HighRiskAttacks = [
  { stageNo: 6, stageType: "normal", monsterType: "normal", attack: 36 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", attack: 52 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", attack: 70 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", attack: 88 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", attack: 110 },
]

migrate((app) => {
  for (const balance of chapter2HighRiskAttacks) {
    const stages = app.findRecordsByFilter(
      "stages",
      `stage_no=${balance.stageNo} && stage_type="${balance.stageType}" && is_active=true`,
      "",
      10,
      0,
    )
    if (stages.length === 0) throw new Error(`active chapter 2 stage ${balance.stageNo} not found`)

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
    if (updated === 0) throw new Error(`chapter 2 stage ${balance.stageNo} monster attack was not updated`)
  }

  console.log("[chapter2-high-risk] raised attacks to 36/52/70/88/110 while preserving low HP and defense")
}, (app) => {
  // Keep chapter 2 high-risk combat pressure on rollback.
})
