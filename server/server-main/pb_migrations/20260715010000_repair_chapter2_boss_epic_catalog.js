const chapter2BossEpics = [
  ["맹독 암살자 단검", "weapon", "sword", "dagger", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_dagger.png", 950, 0, 38, 0, 45, "맹독 암살자 세트의 에픽 단검입니다. 공격력 +38, 민첩 +45."],
  ["맹독 암살자 복면", "helmet", "helmet", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_helmet.png", 520, 140, 4, 7, 18, "맹독 암살자 세트의 에픽 복면입니다. HP +140, 공격력 +4, 방어력 +7, 민첩 +18."],
  ["맹독 암살자 갑옷", "armor", "armor", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_armor.png", 680, 210, 6, 24, 14, "맹독 암살자 세트의 에픽 갑옷입니다. HP +210, 공격력 +6, 방어력 +24, 민첩 +14."],
  ["맹독 암살자 장화", "shoes", "shoes", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_boots.png", 520, 110, 3, 5, 28, "맹독 암살자 세트의 에픽 장화입니다. HP +110, 공격력 +3, 방어력 +5, 민첩 +28."],
]

migrate((app) => {
  const names = chapter2BossEpics.map((item) => item[0])
  const bindings = { weapon: names[0], helmet: names[1], armor: names[2], shoes: names[3] }

  for (const [name, pieceType, slot, weaponType, imagePath, price, hp, attack, defense, agility, description] of chapter2BossEpics) {
    app.db().newQuery(`
      UPDATE item_templates
      SET set_key = 'poison_assassin', set_piece_type = {:pieceType}, equipment_slot = {:slot},
          weapon_type = {:weaponType}, image_path = {:imagePath}, price_coin = {:price},
          base_hp = {:hp}, base_attack = {:attack}, base_defense = {:defense},
          base_agility = {:agility}, description = {:description}, is_active = TRUE
      WHERE name = {:name} AND rarity = 'epic'
    `).bind({ name, pieceType, slot, weaponType, imagePath, price, hp, attack, defense, agility, description }).execute()
  }

  app.db().newQuery(`
    UPDATE item_templates
    SET is_active = FALSE
    WHERE rarity = 'epic' AND set_key = 'poison_assassin'
      AND name NOT IN ({:weapon}, {:helmet}, {:armor}, {:shoes})
  `).bind(bindings).execute()

  app.db().newQuery(`
    UPDATE shop_items
    SET is_active = FALSE
    WHERE item_template IN (
      SELECT id FROM item_templates
      WHERE rarity = 'epic' AND set_key = 'poison_assassin'
        AND name NOT IN ({:weapon}, {:helmet}, {:armor}, {:shoes})
    )
  `).bind(bindings).execute()
}, (app) => {
  // Canonical chapter 2 boss equipment remains configured on rollback.
})
