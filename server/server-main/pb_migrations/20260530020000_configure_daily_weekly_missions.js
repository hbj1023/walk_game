migrate((app) => {
  const missionsCollection = app.findCollectionByNameOrId("missions")

  const missionTypeField = missionsCollection.fields.find((field) => field.name === "mission_type")
  if (missionTypeField) {
    missionTypeField.values = ["daily", "weekly"]
  }

  const targetTypeField = missionsCollection.fields.find((field) => field.name === "target_type")
  if (targetTypeField) {
    targetTypeField.values = ["distance", "normal_stage_clear", "boss_stage_clear"]
  }

  app.save(missionsCollection)

  const upsertByFilter = (collectionName, filter, values) => {
    const collection = app.findCollectionByNameOrId(collectionName)
    const existing = app.findRecordsByFilter(collectionName, filter, "", 1, 0)
    const record = existing.length > 0 ? existing[0] : new Record(collection)
    for (const [key, value] of Object.entries(values)) {
      record.set(key, value)
    }
    app.save(record)
    return record
  }

  const missionDefinitions = [
    { title: "500m 걷기", mission_type: "daily", target_type: "distance", target_value: 500, reward_coin: 50 },
    { title: "1km 걷기", mission_type: "daily", target_type: "distance", target_value: 1000, reward_coin: 100 },
    { title: "1.5km 걷기", mission_type: "daily", target_type: "distance", target_value: 1500, reward_coin: 150 },
    { title: "2km 걷기", mission_type: "daily", target_type: "distance", target_value: 2000, reward_coin: 200 },
    { title: "일반 스테이지 3회 클리어", mission_type: "daily", target_type: "normal_stage_clear", target_value: 3, reward_coin: 150 },
    { title: "보스 스테이지 1회 클리어", mission_type: "daily", target_type: "boss_stage_clear", target_value: 1, reward_coin: 300 },
    { title: "보스 스테이지 7회 클리어", mission_type: "weekly", target_type: "boss_stage_clear", target_value: 7, reward_coin: 1200 },
    { title: "2.5km 걷기", mission_type: "weekly", target_type: "distance", target_value: 2500, reward_coin: 300 },
    { title: "3km 걷기", mission_type: "weekly", target_type: "distance", target_value: 3000, reward_coin: 350 },
    { title: "4km 걷기", mission_type: "weekly", target_type: "distance", target_value: 4000, reward_coin: 450 },
    { title: "5km 걷기", mission_type: "weekly", target_type: "distance", target_value: 5000, reward_coin: 600 },
    { title: "일반 스테이지 20회 클리어", mission_type: "weekly", target_type: "normal_stage_clear", target_value: 20, reward_coin: 900 },
  ]

  const activeTitles = new Set()
  for (const mission of missionDefinitions) {
    activeTitles.add(mission.title)
    const values = { is_active: true }
    for (const [key, value] of Object.entries(mission)) {
      values[key] = value
    }
    upsertByFilter("missions", `title="${mission.title}"`, values)
  }

  const missionRecords = app.findRecordsByFilter("missions", `is_active=true`, "", 500, 0)
  for (const mission of missionRecords) {
    const targetType = mission.get("target_type")
    if (
      (targetType === "distance" || targetType === "normal_stage_clear" || targetType === "boss_stage_clear") &&
      !activeTitles.has(mission.get("title"))
    ) {
      mission.set("is_active", false)
      app.save(mission)
    }
  }
}, (app) => {
  // Keep live mission content on rollback.
})
