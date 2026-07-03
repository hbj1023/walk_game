migrate((app) => {
  const ensureTextField = (collection, fieldName, max = 0) => {
    try {
      collection.fields.getByName(fieldName)
      return false
    } catch (_) {}

    collection.fields.add(new TextField({
      name: fieldName,
      max,
    }))
    return true
  }

  const ensureSelectField = (collection, fieldName, values) => {
    try {
      const field = collection.fields.getByName(fieldName)
      let changed = false
      for (const value of values) {
        if (!field.values.includes(value)) {
          field.values.push(value)
          changed = true
        }
      }
      return changed
    } catch (_) {}

    collection.fields.add(new SelectField({
      name: fieldName,
      maxSelect: 1,
      values,
    }))
    return true
  }

  const itemTemplates = app.findCollectionByNameOrId("item_templates")
  let itemTemplatesChanged = false
  itemTemplatesChanged = ensureTextField(itemTemplates, "set_key", 80) || itemTemplatesChanged
  itemTemplatesChanged = ensureSelectField(itemTemplates, "set_piece_type", ["weapon", "helmet", "armor", "shoes"]) || itemTemplatesChanged
  itemTemplatesChanged = ensureTextField(itemTemplates, "image_path", 255) || itemTemplatesChanged
  if (itemTemplatesChanged) app.save(itemTemplates)

  try {
    app.findCollectionByNameOrId("equipment_set_bonuses")
  } catch (_) {
    const collection = new Collection({
      id: "pbc_2070306000",
      type: "base",
      name: "equipment_set_bonuses",
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        { name: "set_key", type: "text", required: true, max: 80 },
        { name: "set_name", type: "text", required: true, max: 80 },
        { name: "required_count", type: "number", required: true, onlyInt: true, min: 3, max: 4 },
        {
          name: "bonus_type",
          type: "select",
          required: true,
          maxSelect: 1,
          values: [
            "attack_percent",
            "defense_percent",
            "hp_percent",
            "agility_percent",
            "damage_taken_percent",
            "monster_gauge_percent",
            "boss_damage_percent",
            "attack_distance_percent",
          ],
        },
        { name: "bonus_value", type: "number", required: true },
        { name: "description", type: "text", max: 255 },
        { name: "is_active", type: "bool" },
      ],
      indexes: [
        "CREATE INDEX idx_equipment_set_bonuses_set_key ON equipment_set_bonuses (set_key)",
      ],
    })
    app.save(collection)
  }

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

  const setConfigs = [
    {
      key: "vanguard",
      name: "Vanguard",
      weaponType: "sword",
      weaponName: "Vanguard Sword",
      stats: {
        weapon: { attack: 18, defense: 2, price: 2600 },
        helmet: { hp: 80, defense: 6, price: 1900 },
        armor: { hp: 120, defense: 10, price: 2400 },
        shoes: { hp: 40, agility: 8, defense: 2, price: 1700 },
      },
      bonuses: [
        { count: 3, type: "hp_percent", value: 5, description: "3 armor pieces: HP +5%" },
        { count: 4, type: "damage_taken_percent", value: -3, description: "Full set: damage taken -3%" },
      ],
    },
    {
      key: "berserker",
      name: "Berserker",
      weaponType: "axe",
      weaponName: "Berserker Axe",
      stats: {
        weapon: { attack: 24, agility: -4, price: 2850 },
        helmet: { attack: 5, hp: 50, price: 1950 },
        armor: { attack: 8, defense: 5, hp: 80, price: 2500 },
        shoes: { attack: 4, agility: 4, price: 1750 },
      },
      bonuses: [
        { count: 3, type: "attack_percent", value: 5, description: "3 armor pieces: attack +5%" },
        { count: 4, type: "attack_percent", value: 10, description: "Full set: attack +10%" },
      ],
    },
    {
      key: "sentinel",
      name: "Sentinel",
      weaponType: "spear",
      weaponName: "Sentinel Spear",
      stats: {
        weapon: { attack: 16, defense: 6, price: 2700 },
        helmet: { defense: 8, hp: 60, price: 1950 },
        armor: { defense: 14, hp: 110, price: 2500 },
        shoes: { defense: 4, agility: 6, price: 1750 },
      },
      bonuses: [
        { count: 3, type: "defense_percent", value: 8, description: "3 armor pieces: defense +8%" },
        { count: 4, type: "monster_gauge_percent", value: -8, description: "Full set: monster attack gauge -8%" },
      ],
    },
    {
      key: "shadow",
      name: "Shadow",
      weaponType: "dagger",
      weaponName: "Shadow Dagger",
      stats: {
        weapon: { attack: 12, agility: 16, price: 2750 },
        helmet: { agility: 8, hp: 45, price: 1950 },
        armor: { agility: 10, defense: 5, hp: 70, price: 2450 },
        shoes: { agility: 14, price: 1800 },
      },
      bonuses: [
        { count: 3, type: "agility_percent", value: 8, description: "3 armor pieces: agility +8%" },
        { count: 4, type: "attack_distance_percent", value: -8, description: "Full set: attack distance -8%" },
      ],
    },
    {
      key: "colossus",
      name: "Colossus",
      weaponType: "greatsword",
      weaponName: "Colossus Greatsword",
      stats: {
        weapon: { attack: 30, agility: -8, price: 3100 },
        helmet: { attack: 4, defense: 5, hp: 70, price: 2050 },
        armor: { attack: 6, defense: 9, hp: 130, price: 2650 },
        shoes: { attack: 3, agility: 2, hp: 35, price: 1850 },
      },
      bonuses: [
        { count: 3, type: "attack_percent", value: 8, description: "3 armor pieces: attack +8%" },
        { count: 4, type: "boss_damage_percent", value: 10, description: "Full set: boss damage +10%" },
      ],
    },
  ]

  const slotNames = {
    helmet: "Helm",
    armor: "Armor",
    shoes: "Boots",
  }

  for (const set of setConfigs) {
    upsertByFilter("item_templates", `name="${set.weaponName}"`, {
      name: set.weaponName,
      item_type: "equipment",
      equipment_slot: "sword",
      weapon_type: set.weaponType,
      set_key: set.key,
      set_piece_type: "weapon",
      rarity: "legendary",
      base_hp: 0,
      base_attack: set.stats.weapon.attack || 0,
      base_defense: set.stats.weapon.defense || 0,
      base_agility: set.stats.weapon.agility || 0,
      price_coin: set.stats.weapon.price,
      description: `${set.name} set weapon.`,
      is_active: false,
    })

    for (const slot of ["helmet", "armor", "shoes"]) {
      const values = set.stats[slot]
      upsertByFilter("item_templates", `name="${set.name} ${slotNames[slot]}"`, {
        name: `${set.name} ${slotNames[slot]}`,
        item_type: "equipment",
        equipment_slot: slot,
        weapon_type: "",
        set_key: set.key,
        set_piece_type: slot,
        rarity: "legendary",
        base_hp: values.hp || 0,
        base_attack: values.attack || 0,
        base_defense: values.defense || 0,
        base_agility: values.agility || 0,
        price_coin: values.price,
        description: `${set.name} set ${slot}.`,
        is_active: false,
      })
    }

    for (const bonus of set.bonuses) {
      upsertByFilter(
        "equipment_set_bonuses",
        `set_key="${set.key}" && required_count=${bonus.count} && bonus_type="${bonus.type}"`,
        {
          set_key: set.key,
          set_name: set.name,
          required_count: bonus.count,
          bonus_type: bonus.type,
          bonus_value: bonus.value,
          description: bonus.description,
          is_active: true,
        },
      )
    }
  }
}, (app) => {
  // Keep chapter 2 set foundations on rollback.
})
