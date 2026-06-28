migrate((app) => {
  const updates = [
    {
      id: "z606g1s0a4m8lxd",
      hp: 90,
      attack: 10,
      defense: 1,
      agility: 4,
    },
    {
      id: "79m8wj0139u3752",
      hp: 130,
      attack: 13,
      defense: 2,
      agility: 5,
    },
    {
      id: "97n9gpt2g5o581w",
      hp: 190,
      attack: 17,
      defense: 4,
      agility: 6,
    },
    {
      id: "oy2ycgv98oi97g3",
      hp: 260,
      attack: 22,
      defense: 6,
      agility: 7,
    },
  ]

  for (const update of updates) {
    const monster = app.findRecordById("monsters", update.id)
    if (monster.get("monster_type") !== "normal") {
      continue
    }

    monster.set("hp", update.hp)
    monster.set("attack", update.attack)
    monster.set("defense", update.defense)
    monster.set("agility", update.agility)
    app.save(monster)
  }
}, (app) => {
  const ids = [
    "z606g1s0a4m8lxd",
    "79m8wj0139u3752",
    "97n9gpt2g5o581w",
    "oy2ycgv98oi97g3",
  ]

  for (const id of ids) {
    const monster = app.findRecordById("monsters", id)
    if (monster.get("monster_type") !== "normal") {
      continue
    }

    monster.set("hp", 0)
    monster.set("attack", 0)
    monster.set("defense", 0)
    monster.set("agility", 0)
    app.save(monster)
  }
})
