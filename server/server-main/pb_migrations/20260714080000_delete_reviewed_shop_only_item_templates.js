const reviewedShopOnlyDeletionIDs = [
  "uw8y6tnc3he4im8",
  "nka369hv4he3ygr",
  "f18z5tu3q8c29q4",
  "68ld47176amj1w4",
  "zvi077my8z0h89f",
  "d054a2yz187g790",
  "xq625ll2p31p981",
  "y5rz1rs7nsv0c9h",
  "7lsds18mu8m9c77",
  "zo306d64r9sg849",
  "lh7ww3838w43101",
  "q7p998qks2op99k",
  "340dk6936ccdep1",
  "42etmynnprew044",
  "5etx2f3qao884tk",
  "4xvpb7hfppew622",
  "0262hh116qp0vpm",
  "eeych9ppsq33o58",
  "xlyb7tlh2o3i94p",
  "81nphh2o7k8w8t2",
  "362v3v93c763j55",
  "lwa81jtb3dw2uet",
  "rgtz6w5ave94f35",
  "d42rn1ny68lr9lx",
  "s074g90879v2n6w",
  "jl286u37cu39993",
  "5ycq9g01sst254g",
  "355tyda8431od06",
  "h1el546t1c204ki",
  "tl92vis895s4hjz",
  "6361z5fga79do87",
  "m2oh3a0k8z2xt4s",
  "a3859h3aox56004",
  "2s54f49614xld63",
  "uj7i37n44h2jar2",
]

const protectedReferenceFields = [
  ["owned_equipments", "item_template"],
  ["character_consumables", "item_template"],
  ["daily_shop_offers", "item_template"],
  ["monster_drop_items", "item_template"],
  ["reward_logs", "reward_item_template"],
]

const hasProtectedReference = (app, templateID) => {
  for (const [collectionName, fieldName] of protectedReferenceFields) {
    const records = app.findRecordsByFilter(
      collectionName,
      `${fieldName}="${templateID}"`,
      "",
      1,
      0,
    )
    if (records.length > 0) return true
  }
  return false
}

migrate((app) => {
  let deletedCount = 0
  let deletedShopLinks = 0
  let skippedCount = 0

  for (const templateID of reviewedShopOnlyDeletionIDs) {
    let template
    try {
      template = app.findRecordById("item_templates", templateID)
    } catch (_) {
      skippedCount += 1
      continue
    }

    if (Boolean(template.get("is_active")) || hasProtectedReference(app, templateID)) {
      console.log(`[item-catalog-cleanup] skipped protected ${templateID} ${template.get("name")}`)
      skippedCount += 1
      continue
    }

    const shopItems = app.findRecordsByFilter(
      "shop_items",
      `item_template="${templateID}"`,
      "",
      100,
      0,
    )
    for (const shopItem of shopItems) {
      app.delete(shopItem)
      deletedShopLinks += 1
    }

    console.log(`[item-catalog-cleanup] deleting shop-only ${templateID} ${template.get("name")}`)
    app.delete(template)
    deletedCount += 1
  }

  console.log(
    `[item-catalog-cleanup] shop-only deleted=${deletedCount} shop-links=${deletedShopLinks} skipped=${skippedCount}`,
  )
}, (app) => {
  // Reviewed deletions are intentionally irreversible.
})
