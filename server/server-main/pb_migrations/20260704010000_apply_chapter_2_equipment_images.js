migrate((app) => {
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

  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && (set_key="vanguard" || set_key="berserker" || set_key="sentinel" || set_key="shadow" || set_key="colossus")`,
    "",
    500,
    0,
  )

  for (const template of templates) {
    const setKey = String(template.get("set_key") || "")
    const pieceType = String(template.get("set_piece_type") || "")
    const weaponType = String(template.get("weapon_type") || "")
    let imagePath = ""

    if (pieceType === "weapon") {
      imagePath = weaponImages[weaponType] || ""
    } else {
      imagePath = armorImages[setKey] || ""
    }

    if (!imagePath) continue
    template.set("image_path", imagePath)
    app.save(template)
  }
}, (app) => {
  // Keep live image assignments on rollback.
})
