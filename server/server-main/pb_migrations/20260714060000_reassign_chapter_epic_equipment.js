migrate((app) => {
  const updates = [
    ["에픽 검", "", "weapon", "sword", "sword", "assets/images/equipment/chapter1/epic_green_brass_sword.png"],
    ["에픽 투구", "", "helmet", "helmet", "", "assets/images/equipment/chapter1/epic_green_brass_helmet.png"],
    ["에픽 갑옷", "", "armor", "armor", "", "assets/images/equipment/chapter1/epic_green_brass_armor.png"],
    ["에픽 신발", "", "shoes", "shoes", "", "assets/images/equipment/chapter1/epic_green_brass_boots.png"],
    ["맹독 암살자 단검", "poison_assassin", "weapon", "sword", "dagger", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_dagger.png"],
    ["맹독 암살자 복면", "poison_assassin", "helmet", "helmet", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_helmet.png"],
    ["맹독 암살자 갑옷", "poison_assassin", "armor", "armor", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_armor.png"],
    ["맹독 암살자 장화", "poison_assassin", "shoes", "shoes", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_boots.png"],
  ]

  for (const [name, setKey, pieceType, slot, weaponType, imagePath] of updates) {
    app.db().newQuery(`
      UPDATE item_templates
      SET set_key = {:setKey},
          set_piece_type = {:pieceType},
          equipment_slot = {:slot},
          weapon_type = {:weaponType},
          image_path = {:imagePath},
          is_active = TRUE
      WHERE name = {:name} AND rarity = 'epic'
    `).bind({ name, setKey, pieceType, slot, weaponType, imagePath }).execute()
  }

  app.db().newQuery(`
    UPDATE shop_items
    SET is_active = TRUE
    WHERE item_template IN (
      SELECT id FROM item_templates
      WHERE rarity = 'epic'
        AND (name LIKE '에픽 %' OR name LIKE '맹독 암살자 %')
    )
  `).execute()
}, (app) => {
  // Canonical chapter equipment assignments are preserved on rollback.
})
