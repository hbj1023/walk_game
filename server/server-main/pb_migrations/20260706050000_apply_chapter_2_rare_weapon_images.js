migrate((app) => {
  const rareWeaponImages = {
    sword: "assets/images/equipment/chapter2/ch2_weapon_rare_sword.png",
    axe: "assets/images/equipment/chapter2/ch2_weapon_rare_axe.png",
    spear: "assets/images/equipment/chapter2/ch2_weapon_rare_spear.png",
    dagger: "assets/images/equipment/chapter2/ch2_weapon_rare_dagger.png",
    greatsword: "assets/images/equipment/chapter2/ch2_weapon_rare_greatsword.png",
  }

  const setWeaponTypes = {
    vanguard: "sword",
    berserker: "axe",
    sentinel: "spear",
    shadow: "dagger",
    colossus: "greatsword",
  }

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && equipment_slot="sword" && rarity="rare" && is_active=true`,
    "",
    1000,
    0,
  )

  for (const template of templates) {
    const setKey = String(template.get("set_key") || "")
    const weaponType = String(template.get("weapon_type") || setWeaponTypes[setKey] || "")
    const imagePath = rareWeaponImages[weaponType]
    if (!imagePath) continue

    template.set("weapon_type", weaponType)
    template.set("set_piece_type", "weapon")
    template.set("image_path", imagePath)
    app.save(template)
  }
}, (app) => {
  // Keep current chapter 2 rare weapon images on rollback.
})
