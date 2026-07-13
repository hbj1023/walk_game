const chapter2ArmorSets = {
  vanguard: {
    label: "모험가",
    assetKey: "berserker",
    pieceNames: { helmet: "투구", armor: "갑옷", shoes: "장화" },
  },
  berserker: {
    label: "광전사",
    assetKey: "shadow",
    pieceNames: { helmet: "투구", armor: "갑옷", shoes: "장화" },
  },
  sentinel: {
    label: "창술사",
    assetKey: "sentinel",
    pieceNames: { helmet: "투구", armor: "사슬갑옷", shoes: "장화" },
  },
  shadow: {
    label: "도적",
    assetKey: "vanguard",
    pieceNames: { helmet: "두건", armor: "가죽갑옷", shoes: "장화" },
  },
  colossus: {
    label: "견습기사",
    assetKey: "colossus",
    pieceNames: { helmet: "투구", armor: "갑옷", shoes: "장화" },
  },
}

const armorPieceTypes = ["helmet", "armor", "shoes"]

const fieldString = (record, fieldName) => {
  try {
    return String(record.get(fieldName) || "")
  } catch (_) {
    return ""
  }
}

migrate((app) => {
  const templates = app.findRecordsByFilter(
    "item_templates",
    `item_type="equipment" && is_active=true`,
    "",
    5000,
    0,
  )

  for (const template of templates) {
    const setKey = fieldString(template, "set_key").trim().toLowerCase()
    const set = chapter2ArmorSets[setKey]
    if (!set) continue

    const pieceType = fieldString(template, "set_piece_type").trim().toLowerCase()
    const slot = fieldString(template, "equipment_slot").trim().toLowerCase()
    const normalizedPieceType = armorPieceTypes.includes(pieceType) ? pieceType : slot
    if (!armorPieceTypes.includes(normalizedPieceType)) continue

    const rarity = fieldString(template, "rarity").trim().toLowerCase()
    if (rarity !== "common" && rarity !== "rare") continue

    const rarityLabel = rarity === "rare" ? "희귀 " : ""
    const rarityFilePrefix = rarity === "rare" ? "rare_" : ""
    const filePiece = normalizedPieceType === "shoes" ? "boots" : normalizedPieceType

    template.set("set_key", setKey)
    template.set("set_piece_type", normalizedPieceType)
    template.set("equipment_slot", normalizedPieceType)
    template.set(
      "name",
      `${rarityLabel}${set.label} ${set.pieceNames[normalizedPieceType]}`,
    )
    template.set(
      "image_path",
      `assets/images/equipment/chapter2/ch2_armor_${rarityFilePrefix}${set.assetKey}_${filePiece}.png`,
    )
    app.save(template)
  }
}, (app) => {
  // Keep the corrected chapter 2 armor identities on rollback.
})
