migrate((app) => {
  const bonuses = app.findRecordsByFilter(
    "equipment_set_bonuses",
    'set_key="quarry_spearmaster" && required_count=4',
    "",
    10,
    0,
  )
  if (bonuses.length !== 1) {
    throw new Error(`expected one quarry spearmaster 4-set bonus, found ${bonuses.length}`)
  }

  const bonus = bonuses[0]
  bonus.set("bonus_type", "attack_distance_percent")
  bonus.set("bonus_value", -10)
  bonus.set("description", "4\uc138\ud2b8: \ud30c\ud2f0 \uacf5\uaca9 \uac8c\uc774\uc9c0 \ud544\uc694 \uac70\ub9ac -10%")
  app.save(bonus)
}, (app) => {
  const bonuses = app.findRecordsByFilter(
    "equipment_set_bonuses",
    'set_key="quarry_spearmaster" && required_count=4',
    "",
    10,
    0,
  )
  for (const bonus of bonuses) {
    bonus.set("bonus_type", "monster_gauge_percent")
    bonus.set("bonus_value", -10)
    bonus.set("description", "4\uc138\ud2b8: \ubaac\uc2a4\ud130 \uacf5\uaca9 \uac8c\uc774\uc9c0 -10%")
    app.save(bonus)
  }
})
