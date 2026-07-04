migrate((app) => {
  const itemTemplates = app.findCollectionByNameOrId("item_templates")
  let fieldsChanged = false

  const ensureTextField = (fieldName, max = 0) => {
    try {
      itemTemplates.fields.getByName(fieldName)
      return
    } catch (_) {}

    itemTemplates.fields.add(new TextField({
      name: fieldName,
      max,
    }))
    fieldsChanged = true
  }

  const ensureSelectField = (fieldName, values) => {
    try {
      const field = itemTemplates.fields.getByName(fieldName)
      for (const value of values) {
        if (!field.values.includes(value)) {
          field.values.push(value)
          fieldsChanged = true
        }
      }
      return
    } catch (_) {}

    itemTemplates.fields.add(new SelectField({
      name: fieldName,
      maxSelect: 1,
      values,
    }))
    fieldsChanged = true
  }

  ensureSelectField("weapon_type", ["sword", "axe", "spear", "dagger", "greatsword"])
  ensureTextField("set_key", 80)
  ensureSelectField("set_piece_type", ["weapon", "helmet", "armor", "shoes"])
  ensureTextField("image_path", 255)
  if (fieldsChanged) app.save(itemTemplates)

  const sets = {
    vanguard: { name: "Vanguard", weaponType: "sword", weaponName: "Sword" },
    berserker: { name: "Berserker", weaponType: "axe", weaponName: "Axe" },
    sentinel: { name: "Sentinel", weaponType: "spear", weaponName: "Spear" },
    shadow: { name: "Shadow", weaponType: "dagger", weaponName: "Dagger" },
    colossus: { name: "Colossus", weaponType: "greatsword", weaponName: "Greatsword" },
  }

  const weaponImages = {
    sword: "assets/images/equipment/chapter2/ch2_weapon_sword.png",
    axe: "assets/images/equipment/chapter2/ch2_weapon_axe.png",
    spear: "assets/images/equipment/chapter2/ch2_weapon_spear.png",
    dagger: "assets/images/equipment/chapter2/ch2_weapon_dagger.png",
    greatsword: "assets/images/equipment/chapter2/ch2_weapon_colossus.png",
  }

  const armorImages = {
    vanguard: {
      helmet: "assets/images/equipment/chapter2/ch2_armor_vanguard_helmet.png",
      armor: "assets/images/equipment/chapter2/ch2_armor_vanguard_armor.png",
      shoes: "assets/images/equipment/chapter2/ch2_armor_vanguard_boots.png",
    },
    berserker: {
      helmet: "assets/images/equipment/chapter2/ch2_armor_berserker_helmet.png",
      armor: "assets/images/equipment/chapter2/ch2_armor_berserker_armor.png",
      shoes: "assets/images/equipment/chapter2/ch2_armor_berserker_boots.png",
    },
    sentinel: {
      helmet: "assets/images/equipment/chapter2/ch2_armor_sentinel_helmet.png",
      armor: "assets/images/equipment/chapter2/ch2_armor_sentinel_armor.png",
      shoes: "assets/images/equipment/chapter2/ch2_armor_sentinel_boots.png",
    },
    shadow: {
      helmet: "assets/images/equipment/chapter2/ch2_armor_shadow_helmet.png",
      armor: "assets/images/equipment/chapter2/ch2_armor_shadow_armor.png",
      shoes: "assets/images/equipment/chapter2/ch2_armor_shadow_boots.png",
    },
    colossus: {
      helmet: "assets/images/equipment/chapter2/ch2_armor_colossus_helmet.png",
      armor: "assets/images/equipment/chapter2/ch2_armor_colossus_armor.png",
      shoes: "assets/images/equipment/chapter2/ch2_armor_colossus_boots.png",
    },
  }

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment"`,
    "",
    500,
    0,
  )

  for (const template of templates) {
    const name = String(template.get("name") || "")
    let setKey = String(template.get("set_key") || "")
    if (!setKey) {
      for (const [candidateKey, candidate] of Object.entries(sets)) {
        if (name.includes(candidate.name)) {
          setKey = candidateKey
          break
        }
      }
    }

    const set = sets[setKey]
    if (!set) continue

    let pieceType = String(template.get("set_piece_type") || "")
    if (!pieceType) {
      const equipmentSlot = String(template.get("equipment_slot") || "")
      if (equipmentSlot === "sword" || name.endsWith(set.weaponName)) {
        pieceType = "weapon"
      } else if (name.endsWith("Helm")) {
        pieceType = "helmet"
      } else if (name.endsWith("Armor")) {
        pieceType = "armor"
      } else if (name.endsWith("Boots")) {
        pieceType = "shoes"
      } else {
        pieceType = equipmentSlot
      }
    }

    let imagePath = ""

    if (pieceType === "weapon") {
      const weaponType = String(template.get("weapon_type") || set.weaponType)
      imagePath = weaponImages[weaponType] || ""
      template.set("weapon_type", weaponType)
    } else {
      imagePath = (armorImages[setKey] || {})[pieceType] || ""
      template.set("weapon_type", "")
    }

    if (!imagePath) continue
    template.set("set_key", setKey)
    template.set("set_piece_type", pieceType)
    template.set("image_path", imagePath)
    app.save(template)
  }
}, (app) => {
  // Keep live chapter 2 equipment image assignments on rollback.
})
