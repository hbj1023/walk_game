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
  { stageNo: 1, stageType: "normal", monsterType: "normal", hp: 70, attack: 8, defense: 1, agility: 4, rewardCoinMin: 35, rewardCoinMax: 50 },
  { stageNo: 2, stageType: "normal", monsterType: "normal", hp: 105, attack: 10, defense: 2, agility: 5, rewardCoinMin: 55, rewardCoinMax: 80 },
  { stageNo: 3, stageType: "normal", monsterType: "normal", hp: 140, attack: 12, defense: 2, agility: 6, rewardCoinMin: 85, rewardCoinMax: 120 },
  { stageNo: 4, stageType: "normal", monsterType: "normal", hp: 180, attack: 15, defense: 3, agility: 7, rewardCoinMin: 120, rewardCoinMax: 160 },
  { stageNo: 5, stageType: "boss", monsterType: "boss", hp: 310, attack: 22, defense: 5, agility: 5, rewardCoinMin: 300, rewardCoinMax: 420 },
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 700, attack: 38, defense: 9, agility: 8, rewardCoinMin: 260, rewardCoinMax: 340 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 840, attack: 45, defense: 12, agility: 7, rewardCoinMin: 330, rewardCoinMax: 430 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 1020, attack: 54, defense: 15, agility: 10, rewardCoinMin: 430, rewardCoinMax: 560 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 1220, attack: 63, defense: 18, agility: 9, rewardCoinMin: 560, rewardCoinMax: 720 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 1750, attack: 78, defense: 22, agility: 8, rewardCoinMin: 1150, rewardCoinMax: 1500 },
]

const previousValues = [
  { stageNo: 1, stageType: "normal", monsterType: "normal", hp: 75, attack: 8, defense: 1, agility: 4, rewardCoinMin: 30, rewardCoinMax: 50 },
  { stageNo: 2, stageType: "normal", monsterType: "normal", hp: 115, attack: 11, defense: 2, agility: 5, rewardCoinMin: 60, rewardCoinMax: 90 },
  { stageNo: 3, stageType: "normal", monsterType: "normal", hp: 145, attack: 13, defense: 2, agility: 6, rewardCoinMin: 90, rewardCoinMax: 130 },
  { stageNo: 4, stageType: "normal", monsterType: "normal", hp: 185, attack: 16, defense: 3, agility: 7, rewardCoinMin: 130, rewardCoinMax: 180 },
  { stageNo: 5, stageType: "boss", monsterType: "boss", hp: 320, attack: 23, defense: 5, agility: 5, rewardCoinMin: 350, rewardCoinMax: 500 },
  { stageNo: 6, stageType: "normal", monsterType: "normal", hp: 760, attack: 42, defense: 10, agility: 8, rewardCoinMin: 180, rewardCoinMax: 250 },
  { stageNo: 7, stageType: "normal", monsterType: "normal", hp: 900, attack: 49, defense: 14, agility: 7, rewardCoinMin: 240, rewardCoinMax: 330 },
  { stageNo: 8, stageType: "normal", monsterType: "normal", hp: 1080, attack: 58, defense: 16, agility: 11, rewardCoinMin: 320, rewardCoinMax: 430 },
  { stageNo: 9, stageType: "normal", monsterType: "normal", hp: 1280, attack: 68, defense: 19, agility: 9, rewardCoinMin: 410, rewardCoinMax: 540 },
  { stageNo: 10, stageType: "boss", monsterType: "boss", hp: 1850, attack: 82, defense: 24, agility: 8, rewardCoinMin: 850, rewardCoinMax: 1150 },
]

migrate((app) => {
  applyStageMonsterBalance(app, balancedValues)
}, (app) => {
  applyStageMonsterBalance(app, previousValues)
})
