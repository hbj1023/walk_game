const chapter1BossEpics = [
  ["에픽 검", "weapon", "sword", "sword", "assets/images/equipment/chapter1/epic_green_brass_sword.png", 700, 0, 24, 4, 0, "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 검입니다. 공격력 +24, 방어력 +4."],
  ["에픽 투구", "helmet", "helmet", "", "assets/images/equipment/chapter1/epic_green_brass_helmet.png", 380, 80, 0, 0, 0, "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 투구입니다. HP +80."],
  ["에픽 갑옷", "armor", "armor", "", "assets/images/equipment/chapter1/epic_green_brass_armor.png", 430, 0, 0, 14, 0, "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 갑옷입니다. 방어력 +14."],
  ["에픽 신발", "shoes", "shoes", "", "assets/images/equipment/chapter1/epic_green_brass_boots.png", 360, 0, 0, 0, 18, "숲길 보스를 쓰러뜨린 모험가를 위한 에픽 신발입니다. 민첩 +18."],
]

migrate((app) => {
  const names = chapter1BossEpics.map((item) => item[0])

  for (const [name, pieceType, slot, weaponType, imagePath, price, hp, attack, defense, agility, description] of chapter1BossEpics) {
    app.db().newQuery(`
      UPDATE item_templates
      SET set_key = '', set_piece_type = {:pieceType}, equipment_slot = {:slot},
          weapon_type = {:weaponType}, image_path = {:imagePath}, price_coin = {:price},
          base_hp = {:hp}, base_attack = {:attack}, base_defense = {:defense},
          base_agility = {:agility}, description = {:description}, is_active = TRUE
      WHERE name = {:name} AND rarity = 'epic'
    `).bind({ name, pieceType, slot, weaponType, imagePath, price, hp, attack, defense, agility, description }).execute()
  }

  const bindings = { sword: names[0], helmet: names[1], armor: names[2], shoes: names[3] }
  app.db().newQuery(`
    UPDATE shop_items
    SET is_active = FALSE
    WHERE item_template IN (
      SELECT id FROM item_templates
      WHERE rarity = 'epic' AND COALESCE(set_key, '') = ''
        AND name NOT IN ({:sword}, {:helmet}, {:armor}, {:shoes})
    )
  `).bind(bindings).execute()

  app.db().newQuery(`
    UPDATE shop_items
    SET is_active = TRUE,
        price_coin = (SELECT price_coin FROM item_templates WHERE id = shop_items.item_template)
    WHERE item_template IN (
      SELECT id FROM item_templates
      WHERE rarity = 'epic' AND name IN ({:sword}, {:helmet}, {:armor}, {:shoes})
    )
  `).bind(bindings).execute()
}, (app) => {
  // Canonical chapter 1 boss equipment remains available on rollback.
})
