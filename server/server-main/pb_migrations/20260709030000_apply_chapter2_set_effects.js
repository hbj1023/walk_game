const chapter2SetEffects = {
  vanguard: {
    setName: "모험가 세트",
    effects: [
      { count: 3, type: "hp_percent", value: 8, description: "3세트: 최대 HP +8%" },
      { count: 3, type: "defense_percent", value: 8, description: "3세트: 방어력 +8%" },
      { count: 4, type: "attack_percent", value: 6, description: "4세트: 공격력 +6%" },
      { count: 4, type: "damage_taken_percent", value: -4, description: "4세트: 받는 피해 -4%" },
    ],
  },
  berserker: {
    setName: "광전사 세트",
    effects: [
      { count: 3, type: "attack_percent", value: 12, description: "3세트: 공격력 +12%" },
      { count: 3, type: "hp_percent", value: 5, description: "3세트: 최대 HP +5%" },
      { count: 4, type: "boss_damage_percent", value: 15, description: "4세트: 보스에게 주는 피해 +15%" },
      { count: 4, type: "damage_taken_percent", value: 5, description: "4세트: 받는 피해 +5%" },
    ],
  },
  sentinel: {
    setName: "창술사 세트",
    effects: [
      { count: 3, type: "defense_percent", value: 10, description: "3세트: 방어력 +10%" },
      { count: 3, type: "agility_percent", value: 6, description: "3세트: 민첩 +6%" },
      { count: 4, type: "monster_gauge_percent", value: -10, description: "4세트: 몬스터 공격 게이지 -10%" },
      { count: 4, type: "boss_damage_percent", value: 6, description: "4세트: 보스에게 주는 피해 +6%" },
    ],
  },
  shadow: {
    setName: "도적 세트",
    effects: [
      { count: 3, type: "agility_percent", value: 12, description: "3세트: 민첩 +12%" },
      { count: 3, type: "attack_percent", value: 5, description: "3세트: 공격력 +5%" },
      { count: 4, type: "attack_distance_percent", value: -10, description: "4세트: 공격 필요 거리 -10%" },
    ],
  },
  colossus: {
    setName: "견습기사 세트",
    effects: [
      { count: 3, type: "defense_percent", value: 15, description: "3세트: 방어력 +15%" },
      { count: 3, type: "hp_percent", value: 10, description: "3세트: 최대 HP +10%" },
      { count: 4, type: "damage_taken_percent", value: -8, description: "4세트: 받는 피해 -8%" },
      { count: 4, type: "boss_damage_percent", value: 8, description: "4세트: 보스에게 주는 피해 +8%" },
    ],
  },
}

const previousSetEffects = {
  vanguard: [
    { count: 3, type: "hp_percent", value: 5, description: "3세트: 최대 HP +5%" },
    { count: 4, type: "damage_taken_percent", value: -3, description: "4세트: 받는 피해 -3%" },
  ],
  berserker: [
    { count: 3, type: "attack_percent", value: 5, description: "3세트: 공격력 +5%" },
    { count: 4, type: "attack_percent", value: 10, description: "4세트: 공격력 +10%" },
  ],
  sentinel: [
    { count: 3, type: "defense_percent", value: 8, description: "3세트: 방어력 +8%" },
    { count: 4, type: "monster_gauge_percent", value: -8, description: "4세트: 몬스터 공격 게이지 -8%" },
  ],
  shadow: [
    { count: 3, type: "agility_percent", value: 8, description: "3세트: 민첩 +8%" },
    { count: 4, type: "attack_distance_percent", value: -8, description: "4세트: 공격 필요 거리 -8%" },
  ],
  colossus: [
    { count: 3, type: "attack_percent", value: 8, description: "3세트: 공격력 +8%" },
    { count: 4, type: "boss_damage_percent", value: 10, description: "4세트: 보스에게 주는 피해 +10%" },
  ],
}

const setEffectText = (setConfig) => {
  const three = setConfig.effects
    .filter((effect) => effect.count === 3)
    .map((effect) => effect.description.replace(/^3세트:\s*/, ""))
    .join(" / ")
  const four = setConfig.effects
    .filter((effect) => effect.count === 4)
    .map((effect) => effect.description.replace(/^4세트:\s*/, ""))
    .join(" / ")
  return `세트효과 - 3세트: ${three} | 4세트: ${four}`
}

const fieldString = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "")
  } catch (_) {
    return ""
  }
}

const setBonusesActive = (app, setKey, active) => {
  const records = app.findRecordsByFilter("equipment_set_bonuses", `set_key="${setKey}"`, "", 50, 0)
  for (const record of records) {
    record.set("is_active", active)
    app.save(record)
  }
}

const upsertSetBonus = (app, setKey, setName, effect) => {
  const collection = app.findCollectionByNameOrId("equipment_set_bonuses")
  const filter = `set_key="${setKey}" && required_count=${effect.count} && bonus_type="${effect.type}"`
  const existing = app.findRecordsByFilter("equipment_set_bonuses", filter, "", 1, 0)
  const record = existing.length > 0 ? existing[0] : new Record(collection)
  record.set("set_key", setKey)
  record.set("set_name", setName)
  record.set("required_count", effect.count)
  record.set("bonus_type", effect.type)
  record.set("bonus_value", effect.value)
  record.set("description", effect.description)
  record.set("is_active", true)
  app.save(record)
}

const applySetEffects = (app, effectConfig) => {
  for (const [setKey, config] of Object.entries(effectConfig)) {
    setBonusesActive(app, setKey, false)
    for (const effect of config.effects) {
      upsertSetBonus(app, setKey, config.setName, effect)
    }
  }
}

const restoreSetEffects = (app) => {
  for (const [setKey, effects] of Object.entries(previousSetEffects)) {
    setBonusesActive(app, setKey, false)
    const setName = chapter2SetEffects[setKey]?.setName || setKey
    for (const effect of effects) {
      upsertSetBonus(app, setKey, setName, effect)
    }
  }
}

const applyItemDescriptions = (app) => {
  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment"`, "", 3000, 0)
  for (const template of templates) {
    const setKey = fieldString(template, "set_key")
    const setConfig = chapter2SetEffects[setKey]
    if (!setConfig) continue
    const currentDescription = fieldString(template, "description")
    const baseDescription = currentDescription.split("세트효과 -")[0].trim()
    const nextDescription = [baseDescription, setEffectText(setConfig)].filter(Boolean).join(" ")
    template.set("description", nextDescription)
    app.save(template)
  }
}

migrate((app) => {
  applySetEffects(app, chapter2SetEffects)
  applyItemDescriptions(app)
}, (app) => {
  restoreSetEffects(app)
})
