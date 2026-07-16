const chapter3WalkingPacing = [
  { stageNo: 11, stageType: "normal", monsterType: "normal", hp: 220, attack: 65, defense: 22, agility: 4, rewardCoinMin: 450, rewardCoinMax: 600 },
  { stageNo: 12, stageType: "normal", monsterType: "normal", hp: 270, attack: 78, defense: 27, agility: 6, rewardCoinMin: 560, rewardCoinMax: 730 },
  { stageNo: 13, stageType: "normal", monsterType: "normal", hp: 330, attack: 92, defense: 32, agility: 5, rewardCoinMin: 680, rewardCoinMax: 880 },
  { stageNo: 14, stageType: "normal", monsterType: "normal", hp: 400, attack: 108, defense: 38, agility: 3, rewardCoinMin: 850, rewardCoinMax: 1100 },
  { stageNo: 15, stageType: "boss", monsterType: "boss", hp: 520, attack: 128, defense: 46, agility: 2, rewardCoinMin: 1400, rewardCoinMax: 1900 },
]

migrate((app) => {
  for (const balance of chapter3WalkingPacing) {
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
    if (updated === 0) throw new Error(`chapter 3 stage ${balance.stageNo} monster was not updated`)
  }

  console.log("[chapter3-pacing] tuned quarry monsters for 4-11 normal hits and 10-14 boss hits with chapter 3 rare sets")
}, (app) => {
  // Keep the walking-budget chapter 3 pacing on rollback.
})
