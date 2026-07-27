migrate((app) => {
  const golems = app.findRecordsByFilter(
    "monsters",
    `monster_type="raid" && is_active=true && reward_coin_max>0`,
    "",
    10,
    0,
  )
  if (golems.length !== 1) {
    throw new Error(`active rewarded raid monster count=${golems.length}`)
  }

  golems[0].set("hp", 4300)
  golems[0].set("attack", 115)
  golems[0].set("defense", 45)
  app.save(golems[0])

  console.log("[golem-balance] raised difficulty for running-paced chapter 3-3 parties")
}, (app) => {
  // Preserve the live raid balance on rollback.
})
