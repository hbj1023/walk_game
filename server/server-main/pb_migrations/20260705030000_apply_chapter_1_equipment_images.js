migrate((app) => {
  const itemTemplates = app.findCollectionByNameOrId("item_templates")
  let changed = false

  try {
    itemTemplates.fields.getByName("image_path")
  } catch (_) {
    itemTemplates.fields.add(new TextField({
      name: "image_path",
      max: 255,
    }))
    changed = true
  }

  if (changed) app.save(itemTemplates)

  const imageByName = {
    "낡은 모자": "assets/images/equipment/chapter1/tutorial_armor_helmet.png",
    "낡은  갑옷": "assets/images/equipment/chapter1/tutorial_armor_chest.png",
    "낡은 갑옷": "assets/images/equipment/chapter1/tutorial_armor_chest.png",
    "낡은 신발": "assets/images/equipment/chapter1/tutorial_armor_boots.png",
    "튼튼한 모자": "assets/images/equipment/chapter1/stage1_armor_helmet.png",
    "튼튼한 갑옷": "assets/images/equipment/chapter1/stage1_armor_chest.png",
    "튼튼한 신발": "assets/images/equipment/chapter1/stage1_armor_boots.png",
    "초급 검": "assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png",
    "레어 검": "assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png",
    "에픽 검": "assets/images/equipment/chapter1/epic_green_brass_sword.png",
    "에픽 투구": "assets/images/equipment/chapter1/epic_green_brass_helmet.png",
    "에픽 갑옷": "assets/images/equipment/chapter1/epic_green_brass_armor.png",
    "에픽 신발": "assets/images/equipment/chapter1/epic_green_brass_boots.png",
  }

  for (const [name, imagePath] of Object.entries(imageByName)) {
    const templates = app.findRecordsByFilter("item_templates", `name="${name}"`, "", 20, 0)
    for (const template of templates) {
      template.set("image_path", imagePath)
      app.save(template)
    }
  }
}, (app) => {
  // Keep live chapter 1 equipment image assignments on rollback.
})
