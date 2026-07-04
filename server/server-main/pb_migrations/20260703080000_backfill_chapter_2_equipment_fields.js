migrate((app) => {
  const itemTemplates = app.findCollectionByNameOrId("item_templates")
  let changed = false

  const ensureTextField = (fieldName, max = 0) => {
    try {
      itemTemplates.fields.getByName(fieldName)
      return
    } catch (_) {}

    itemTemplates.fields.add(new TextField({
      name: fieldName,
      max,
    }))
    changed = true
  }

  const ensureSelectField = (fieldName, values) => {
    try {
      const field = itemTemplates.fields.getByName(fieldName)
      for (const value of values) {
        if (!field.values.includes(value)) {
          field.values.push(value)
          changed = true
        }
      }
      return
    } catch (_) {}

    itemTemplates.fields.add(new SelectField({
      name: fieldName,
      maxSelect: 1,
      values,
    }))
    changed = true
  }

  ensureTextField("set_key", 80)
  ensureSelectField("set_piece_type", ["weapon", "helmet", "armor", "shoes"])
  ensureTextField("image_path", 255)
  if (changed) app.save(itemTemplates)

  const sets = [
    { key: "vanguard", name: "Vanguard", weaponType: "sword", weaponNames: ["Sword", "Vanguard Sword"] },
    { key: "berserker", name: "Berserker", weaponType: "axe", weaponNames: ["Axe", "Berserker Axe"] },
    { key: "sentinel", name: "Sentinel", weaponType: "spear", weaponNames: ["Spear", "Sentinel Spear"] },
    { key: "shadow", name: "Shadow", weaponType: "dagger", weaponNames: ["Dagger", "Shadow Dagger"] },
    { key: "colossus", name: "Colossus", weaponType: "greatsword", weaponNames: ["Greatsword", "Colossus Greatsword"] },
  ]

  const weaponImages = {
    sword: "assets/images/equipment/chapter2/ch2_weapon_sword.png",
    axe: "assets/images/equipment/chapter2/ch2_weapon_axe.png",
    spear: "assets/images/equipment/chapter2/ch2_weapon_spear.png",
    dagger: "assets/images/equipment/chapter2/ch2_weapon_dagger.png",
    greatsword: "assets/images/equipment/chapter2/ch2_weapon_colossus.png",
  }

  const armorImages = {
    vanguard: "assets/images/equipment/chapter2/ch2_armor_vanguard.png",
    berserker: "assets/images/equipment/chapter2/ch2_armor_berserker.png",
    sentinel: "assets/images/equipment/chapter2/ch2_armor_sentinel.png",
    shadow: "assets/images/equipment/chapter2/ch2_armor_shadow.png",
    colossus: "assets/images/equipment/chapter2/ch2_armor_colossus.png",
  }

  const equipment = app.findRecordsByFilter("item_templates", `item_type="equipment"`, "", 500, 0)
  for (const template of equipment) {
    const name = String(template.get("name") || "")
    const set = sets.find((candidate) => name.includes(candidate.name))
    if (!set) continue

    let pieceType = ""
    let weaponType = ""
    let imagePath = armorImages[set.key]

    if (set.weaponNames.some((weaponName) => name.endsWith(weaponName))) {
      pieceType = "weapon"
      weaponType = set.weaponType
      imagePath = weaponImages[weaponType]
    } else if (name.endsWith("Helm")) {
      pieceType = "helmet"
    } else if (name.endsWith("Armor")) {
      pieceType = "armor"
    } else if (name.endsWith("Boots")) {
      pieceType = "shoes"
    }

    if (!pieceType || !imagePath) continue
    template.set("set_key", set.key)
    template.set("set_piece_type", pieceType)
    template.set("weapon_type", weaponType)
    template.set("image_path", imagePath)
    app.save(template)
  }
}, (app) => {
  // Keep chapter 2 equipment metadata because set bonuses and images depend on it.
})
