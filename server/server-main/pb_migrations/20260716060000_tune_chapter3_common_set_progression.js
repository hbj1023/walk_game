const chapter3ProgressionHP = [
  { stageNo: 11, stageType: "normal", monsterType: "normal", hp: 180 },
  { stageNo: 12, stageType: "normal", monsterType: "normal", hp: 230 },
  { stageNo: 13, stageType: "normal", monsterType: "normal", hp: 280 },
  { stageNo: 14, stageType: "normal", monsterType: "normal", hp: 390 },
  { stageNo: 15, stageType: "boss", monsterType: "boss", hp: 480 },
]

const chapter3SetPenetration = [
  { setKey: "quarry_swordsman", setName: "채석단 검사 세트", value: 30, description: "4세트: 적 방어력 30% 무시" },
  { setKey: "quarry_berserker", setName: "채석단 광전사 세트", value: 20, description: "4세트: 적 방어력 20% 무시" },
  { setKey: "quarry_spearmaster", setName: "채석단 창술사 세트", value: 30, description: "4세트: 적 방어력 30% 무시" },
  { setKey: "quarry_rogue", setName: "채석단 도적 세트", value: 25, description: "4세트: 적 방어력 25% 무시" },
  { setKey: "quarry_knight", setName: "채석단 기사 세트", value: 20, description: "4세트: 적 방어력 20% 무시" },
]

migrate((app) => {
  for (const balance of chapter3ProgressionHP) {
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
        app.save(monster)
        updated++
      }
    }
    if (updated === 0) throw new Error(`chapter 3 stage ${balance.stageNo} monster HP was not updated`)
  }

  const bonusCollection = app.findCollectionByNameOrId("equipment_set_bonuses")
  for (const effect of chapter3SetPenetration) {
    const existing = app.findRecordsByFilter(
      "equipment_set_bonuses",
      `set_key="${effect.setKey}" && required_count=4 && bonus_type="defense_penetration_percent"`,
      "",
      20,
      0,
    )
    const bonus = existing.length > 0 ? existing[0] : new Record(bonusCollection)
    bonus.set("set_key", effect.setKey)
    bonus.set("set_name", effect.setName)
    bonus.set("required_count", 4)
    bonus.set("bonus_type", "defense_penetration_percent")
    bonus.set("bonus_value", effect.value)
    bonus.set("description", effect.description)
    bonus.set("is_active", true)
    app.save(bonus)

    for (let index = 1; index < existing.length; index++) {
      existing[index].set("is_active", false)
      app.save(existing[index])
    }
  }

  console.log("[chapter3-common-sets] tuned stage HP and added 20-30% defense penetration to quarry four-piece sets")
}, (app) => {
  // Keep the chapter 3 common-set progression on rollback.
})
