const chapter3ArmorNames = {
  "채석단 검사": "vanguard",
  "채석단 광전사": "berserker",
  "채석단 창술사": "sentinel",
  "채석단 도적": "shadow",
  "채석단 기사": "colossus",
}

migrate((app) => {
  const templates = app.findRecordsByFilter(
    "item_templates",
    `rarity="common" || rarity="rare"`,
    "",
    5000,
    0,
  )
  for (const template of templates) {
    const name = String(template.get("name") || "").replace(/^\+/, "")
    let armorKey = ""
    for (const [prefix, candidate] of Object.entries(chapter3ArmorNames)) {
      if (name.startsWith(prefix)) {
        armorKey = candidate
        break
      }
    }
    if (!armorKey) continue
    const piece = String(template.get("set_piece_type") || "")
    if (piece === "weapon") continue
    const assetPiece = piece === "shoes" ? "boots" : piece
    if (!["helmet", "armor", "boots"].includes(assetPiece)) continue
    const rarity = String(template.get("rarity") || "") === "rare" ? "rare" : "common"
    template.set("image_path", `assets/images/equipment/chapter3/ch3_${rarity}_${armorKey}_${assetPiece}.png`)
    app.save(template)
  }
}, (app) => {
  // Chapter 3 armor images remain assigned on rollback.
})
