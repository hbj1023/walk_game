const applyStageMonsterBalance = (app, updates) => {
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
    monster.set("reward_coin_min", update.rewardCoinMin)
    monster.set("reward_coin_max", update.rewardCoinMax)
    app.save(monster)
  }
}

const balancedValues = [
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 320, attack: 22, defense: 6, agility: 8, rewardCoinMin: 260, rewardCoinMax: 340 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 470, attack: 30, defense: 8, agility: 7, rewardCoinMin: 330, rewardCoinMax: 430 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 650, attack: 39, defense: 11, agility: 10, rewardCoinMin: 430, rewardCoinMax: 560 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 900, attack: 50, defense: 15, agility: 9, rewardCoinMin: 560, rewardCoinMax: 720 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 1300, attack: 68, defense: 20, agility: 8, rewardCoinMin: 1150, rewardCoinMax: 1500 },
]

const previousValues = [
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 700, attack: 38, defense: 9, agility: 8, rewardCoinMin: 260, rewardCoinMax: 340 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 840, attack: 45, defense: 12, agility: 7, rewardCoinMin: 330, rewardCoinMax: 430 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 1020, attack: 54, defense: 15, agility: 10, rewardCoinMin: 430, rewardCoinMax: 560 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 1220, attack: 63, defense: 18, agility: 9, rewardCoinMin: 560, rewardCoinMax: 720 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 1750, attack: 78, defense: 22, agility: 8, rewardCoinMin: 1150, rewardCoinMax: 1500 },
]

migrate((app) => {
  applyStageMonsterBalance(app, balancedValues)
}, (app) => {
  applyStageMonsterBalance(app, previousValues)
})
