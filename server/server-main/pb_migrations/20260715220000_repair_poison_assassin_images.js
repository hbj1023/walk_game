const poisonAssassinImages = [
  ["\ub9f9\ub3c5 \uc554\uc0b4\uc790 \ub2e8\uac80", "weapon", "sword", "dagger", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_dagger.png"],
  ["\ub9f9\ub3c5 \uc554\uc0b4\uc790 \ubcf5\uba74", "helmet", "helmet", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_helmet.png"],
  ["\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uac11\uc637", "armor", "armor", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_armor.png"],
  ["\ub9f9\ub3c5 \uc554\uc0b4\uc790 \uc7a5\ud654", "shoes", "shoes", "", "assets/images/equipment/chapter2/ch2_epic_poison_assassin_boots.png"],
]

migrate((app) => {
  for (const [name, pieceType, slot, weaponType, imagePath] of poisonAssassinImages) {
    app.db().newQuery(`
      UPDATE item_templates
      SET set_key = 'poison_assassin',
          set_piece_type = {:pieceType},
          equipment_slot = {:slot},
          weapon_type = {:weaponType},
          image_path = {:imagePath},
          is_active = TRUE
      WHERE name = {:name} AND rarity = 'epic'
    `).bind({ name, pieceType, slot, weaponType, imagePath }).execute()
  }
}, (app) => {
  // Keep canonical poison assassin image paths on rollback.
})
