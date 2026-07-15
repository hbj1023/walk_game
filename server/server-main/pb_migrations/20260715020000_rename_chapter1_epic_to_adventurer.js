const chapter1AdventurerNames = [
  ["에픽 검", "모험가의 검", "숲길 보스를 쓰러뜨린 모험가의 검입니다. 공격력 +24, 방어력 +4."],
  ["에픽 투구", "모험가의 투구", "숲길 보스를 쓰러뜨린 모험가의 투구입니다. HP +80."],
  ["에픽 갑옷", "모험가의 갑옷", "숲길 보스를 쓰러뜨린 모험가의 갑옷입니다. 방어력 +14."],
  ["에픽 신발", "모험가의 신발", "숲길 보스를 쓰러뜨린 모험가의 신발입니다. 민첩 +18."],
]

migrate((app) => {
  for (const [oldName, newName, description] of chapter1AdventurerNames) {
    app.db().newQuery(`
      UPDATE item_templates
      SET name = {:newName}, description = {:description}, is_active = TRUE
      WHERE name = {:oldName} AND rarity = 'epic' AND COALESCE(set_key, '') = ''
    `).bind({ oldName, newName, description }).execute()
  }
}, (app) => {
  for (const [oldName, newName] of chapter1AdventurerNames) {
    app.db().newQuery(`
      UPDATE item_templates SET name = {:oldName}
      WHERE name = {:newName} AND rarity = 'epic' AND COALESCE(set_key, '') = ''
    `).bind({ oldName, newName }).execute()
  }
})
