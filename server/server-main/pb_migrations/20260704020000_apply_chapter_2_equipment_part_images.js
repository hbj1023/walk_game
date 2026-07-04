migrate((app) => {
  const sets = {
    vanguard: { weaponType: "sword" },
    berserker: { weaponType: "axe" },
    sentinel: { weaponType: "spear" },
    shadow: { weaponType: "dagger" },
    colossus: { weaponType: "greatsword" },
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
    `item_type="equipment" && set_key!=""`,
    "",
    500,
    0,
  )

  for (const template of templates) {
    const setKey = String(template.get("set_key") || "")
    const set = sets[setKey]
    if (!set) continue

    const pieceType = String(template.get("set_piece_type") || template.get("equipment_slot") || "")
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
    template.set("image_path", imagePath)
    app.save(template)
  }
}, (app) => {
  // Keep live chapter 2 equipment image assignments on rollback.
})
