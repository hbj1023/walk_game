const chapter2WalkingPacing = [
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 160, attack: 24, defense: 4, agility: 8, rewardCoinMin: 230, rewardCoinMax: 310 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 210, attack: 32, defense: 5, agility: 7, rewardCoinMin: 300, rewardCoinMax: 400 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 270, attack: 42, defense: 6, agility: 10, rewardCoinMin: 390, rewardCoinMax: 520 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 330, attack: 54, defense: 8, agility: 9, rewardCoinMin: 500, rewardCoinMax: 660 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 400, attack: 72, defense: 10, agility: 8, rewardCoinMin: 900, rewardCoinMax: 1200 },
]

migrate((app) => {
  for (const balance of chapter2WalkingPacing) {
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
        monster.set("hp", balance.hp)
        monster.set("attack", balance.attack)
        monster.set("defense", balance.defense)
        monster.set("agility", balance.agility)
        monster.set("reward_coin_min", balance.rewardCoinMin)
        monster.set("reward_coin_max", balance.rewardCoinMax)
        app.save(monster)
        updated++
      }
    }
    if (updated === 0) throw new Error(`chapter 2 stage ${balance.stageNo} monster was not updated`)
  }

  console.log("[chapter2-pacing] reduced normal targets to 4-10 hits and boss target to 12-14 hits at rare progression")
}, (app) => {
  // Keep the walking-budget combat pacing on rollback.
})
