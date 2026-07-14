const reviewedDeletionIDs = [
  "kv9637b2j17ij0g",
  "on89cg32a60k74c",
  "o7zo99gka5t95sq",
  "34u7154g56lr5s2",
  "o8bw8i166uz71a6",
  "90i01e4s6ytv2ta",
  "2969w354w1frgib",
  "u372seh8png661s",
  "iba860w6bu7n946",
  "96h64ij1g2u8120",
  "298q9ppa9w6vg13",
  "86y29t30c9z839l",
  "55xcl4qkuzm8k2y",
  "3yr0ky3t7j54069",
  "k118e7h51nq28qu",
  "a7e359h9j06rz3z",
  "z776d5e4ov7itbp",
  "77j3ldwe2g5e30g",
  "864u075sz1dn285",
  "83no0x7er7qx84r",
]

const referenceFields = [
  ["owned_equipments", "item_template"],
  ["character_consumables", "item_template"],
  ["shop_items", "item_template"],
  ["daily_shop_offers", "item_template"],
  ["monster_drop_items", "item_template"],
  ["reward_logs", "reward_item_template"],
]

const isStillUnreferenced = (app, templateID) => {
  for (const [collectionName, fieldName] of referenceFields) {
    const records = app.findRecordsByFilter(
      collectionName,
      `${fieldName}="${templateID}"`,
      "",
      1,
      0,
    )
    if (records.length > 0) return false
  }
  return true
}

migrate((app) => {
  let deletedCount = 0
  let skippedCount = 0

  for (const templateID of reviewedDeletionIDs) {
    let template
    try {
      template = app.findRecordById("item_templates", templateID)
    } catch (_) {
      skippedCount += 1
      continue
    }

    if (Boolean(template.get("is_active")) || !isStillUnreferenced(app, templateID)) {
      console.log(`[item-catalog-cleanup] skipped ${templateID} ${template.get("name")}`)
      skippedCount += 1
      continue
    }

    console.log(`[item-catalog-cleanup] deleting ${templateID} ${template.get("name")}`)
    app.delete(template)
    deletedCount += 1
  }

  console.log(`[item-catalog-cleanup] deleted=${deletedCount} skipped=${skippedCount}`)
}, (app) => {
  // Reviewed deletions are intentionally irreversible.
})
