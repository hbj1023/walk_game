const findField = (collection, name) => {
  try {
    return collection.fields.getByName(name)
  } catch (_) {
    return null
  }
}

migrate((app) => {
  const summaries = app.findCollectionByNameOrId("daily_step_summaries")
  if (!findField(summaries, "mission_distance_m")) {
    summaries.fields.add(new NumberField({
      name: "mission_distance_m",
      onlyInt: true,
      min: 0,
    }))
    app.save(summaries)
  }
}, (app) => {
  const summaries = app.findCollectionByNameOrId("daily_step_summaries")
  const field = findField(summaries, "mission_distance_m")
  if (field) {
    summaries.fields.removeByName("mission_distance_m")
    app.save(summaries)
  }
})
