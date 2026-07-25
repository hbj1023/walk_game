migrate((app) => {
  const collection = app.findCollectionByNameOrId("gold_mine_event_runs")

  if (!collection.fields.getByName("remaining_seconds")) {
    collection.fields.add(new NumberField({
      name: "remaining_seconds",
      onlyInt: true,
      min: 0,
      max: 180,
      required: false,
    }))
  }

  const status = collection.fields.getByName("status")
  if (status && !status.values.includes("paused")) {
    status.values = [...status.values, "paused"]
  }

  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("gold_mine_event_runs")
  const status = collection.fields.getByName("status")
  if (status) {
    status.values = status.values.filter((value) => value !== "paused")
  }
  const remaining = collection.fields.getByName("remaining_seconds")
  if (remaining) {
    collection.fields.removeById(remaining.id)
  }
  app.save(collection)
})
