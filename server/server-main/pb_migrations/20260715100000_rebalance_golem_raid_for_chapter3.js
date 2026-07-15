migrate((app) => {
  const monsters = app.findRecordsByFilter(
    "monsters",
    `name="골렘" && monster_type="raid"`,
    "",
    1,
    0,
  )

  if (monsters.length === 0) {
    throw new Error("golem raid monster was not found")
  }

  const golem = monsters[0]
  golem.set("hp", 4000)
  golem.set("attack", 80)
  golem.set("defense", 24)
  golem.set("agility", 3)
  golem.set("reward_coin_min", 2200)
  golem.set("reward_coin_max", 2800)
  golem.set("is_active", true)
  app.save(golem)
}, (app) => {
  // Keep the latest live raid balance on rollback.
})
