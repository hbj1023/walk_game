const chapter2HighRiskPacing = [
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 210, attack: 24, defense: 5, agility: 8, rewardCoinMin: 230, rewardCoinMax: 310 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 290, attack: 32, defense: 7, agility: 7, rewardCoinMin: 300, rewardCoinMax: 400 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 390, attack: 42, defense: 9, agility: 10, rewardCoinMin: 390, rewardCoinMax: 520 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 520, attack: 54, defense: 12, agility: 9, rewardCoinMin: 500, rewardCoinMax: 660 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 760, attack: 72, defense: 16, agility: 8, rewardCoinMin: 900, rewardCoinMax: 1200 },
]

migrate((app) => {
  for (const balance of chapter2HighRiskPacing) {
    const stages = app.findRecordsByFilter(
      "stages",
      `stage_no=${balance.stageNo} && stage_type="${balance.stageType}" && is_active=true`,
      "",
      10,
      0,
    )
    if (stages.length === 0) {
      throw new Error(`active chapter 2 stage ${balance.stageNo} not found`)
    }

    for (const stage of stages) {
      const links = app.findRecordsByFilter(
        "stage_monsters",
        `stage="${stage.id}" && spawn_order=1`,
        "",
        10,
        0,
      )
      if (links.length === 0) {
        throw new Error(`monster link for stage ${balance.stageNo} not found`)
      }

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
      }
    }
  }
}, (app) => {
  // Keep the chapter 2 high-risk pacing on rollback.
})
