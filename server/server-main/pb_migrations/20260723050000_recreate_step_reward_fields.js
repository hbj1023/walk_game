migrate((app) => {
  const summaries = app.findCollectionByNameOrId("daily_step_summaries")
  const fields = [
    { name: "boss_ticket_fragment_earned", onlyInt: true },
    { name: "boss_ticket_fragment_distance_remainder_m", onlyInt: false },
    { name: "mission_distance_m", onlyInt: true },
  ]

  for (const field of fields) {
    try {
      summaries.fields.removeByName(field.name)
      console.log(`[step-reward-fields] removed ${field.name}`)
    } catch (_) {
      console.log(`[step-reward-fields] ${field.name} was missing`)
    }

    summaries.fields.add(new NumberField({
      name: field.name,
      onlyInt: field.onlyInt,
      min: 0,
    }))
    console.log(`[step-reward-fields] added ${field.name}`)
  }

  app.save(summaries)
  console.log("[step-reward-fields] saved daily_step_summaries")
}, (app) => {
  // Keep these fields because step rewards and online-only missions depend on them.
})
