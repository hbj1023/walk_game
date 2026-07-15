const chapter3ArmorSets = {
  quarry_swordsman: "vanguard",
  quarry_berserker: "berserker",
  quarry_spearmaster: "sentinel",
  quarry_rogue: "shadow",
  quarry_knight: "colossus",
}

migrate((app) => {
  for (const setKey of Object.keys(chapter3ArmorSets)) {
    const templates = app.findRecordsByFilter(
      "item_templates",
      `set_key="${setKey}" && (rarity="common" || rarity="rare")`,
      "",
      100,
      0,
    )
    for (const template of templates) {
      const piece = String(template.get("set_piece_type") || "")
      if (piece === "weapon") continue
      const assetPiece = piece === "shoes" ? "boots" : piece
      if (!["helmet", "armor", "boots"].includes(assetPiece)) continue
      const rarity = String(template.get("rarity") || "") === "rare" ? "rare" : "common"
      const armorKey = chapter3ArmorSets[setKey]
      template.set("image_path", `assets/images/equipment/chapter3/ch3_${rarity}_${armorKey}_${assetPiece}.png`)
      app.save(template)
    }
  }
}, (app) => {
  // Chapter 3 armor images remain assigned on rollback.
})
