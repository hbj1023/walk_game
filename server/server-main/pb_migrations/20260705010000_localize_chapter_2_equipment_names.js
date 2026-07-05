migrate((app) => {
  const itemTemplates = app.findCollectionByNameOrId("item_templates")
  let fieldsChanged = false

  const ensureTextField = (fieldName, max = 0) => {
    try {
      itemTemplates.fields.getByName(fieldName)
      return
    } catch (_) {}

    itemTemplates.fields.add(new TextField({
      name: fieldName,
      max,
    }))
    fieldsChanged = true
  }

  const ensureSelectField = (fieldName, values) => {
    try {
      const field = itemTemplates.fields.getByName(fieldName)
      for (const value of values) {
        if (!field.values.includes(value)) {
          field.values.push(value)
          fieldsChanged = true
        }
      }
      return
    } catch (_) {}

    itemTemplates.fields.add(new SelectField({
      name: fieldName,
      maxSelect: 1,
      values,
    }))
    fieldsChanged = true
  }

  ensureSelectField("weapon_type", ["sword", "axe", "spear", "dagger", "greatsword"])
  ensureTextField("set_key", 80)
  ensureSelectField("set_piece_type", ["weapon", "helmet", "armor", "shoes"])
  ensureTextField("image_path", 255)
  if (fieldsChanged) app.save(itemTemplates)

  const rarityLabels = {
    common: "일반",
    rare: "희귀",
    epic: "에픽",
  }

  const sets = {
    vanguard: {
      oldName: "Vanguard",
      setName: "모험가 세트",
      weaponType: "sword",
      weaponName: "검",
      pieceNames: {
        helmet: "모험가 투구",
        armor: "모험가 갑옷",
        shoes: "모험가 장화",
      },
      images: {
        weapon: "assets/images/equipment/chapter2/ch2_weapon_sword.png",
        helmet: "assets/images/equipment/chapter2/ch2_armor_berserker_helmet.png",
        armor: "assets/images/equipment/chapter2/ch2_armor_berserker_armor.png",
        shoes: "assets/images/equipment/chapter2/ch2_armor_berserker_boots.png",
      },
      descriptions: {
        3: "3세트: 최대 HP +5%",
        4: "4세트: 받는 피해 -3%",
      },
    },
    berserker: {
      oldName: "Berserker",
      setName: "광전사 세트",
      weaponType: "axe",
      weaponName: "도끼",
      pieceNames: {
        helmet: "광전사 투구",
        armor: "광전사 갑옷",
        shoes: "광전사 장화",
      },
      images: {
        weapon: "assets/images/equipment/chapter2/ch2_weapon_axe.png",
        helmet: "assets/images/equipment/chapter2/ch2_armor_shadow_helmet.png",
        armor: "assets/images/equipment/chapter2/ch2_armor_shadow_armor.png",
        shoes: "assets/images/equipment/chapter2/ch2_armor_shadow_boots.png",
      },
      descriptions: {
        3: "3세트: 공격력 +5%",
        4: "4세트: 공격력 추가 +10%",
      },
    },
    sentinel: {
      oldName: "Sentinel",
      setName: "창술사 세트",
      weaponType: "spear",
      weaponName: "창",
      pieceNames: {
        helmet: "창술사 투구",
        armor: "창술사 사슬갑옷",
        shoes: "창술사 장화",
      },
      images: {
        weapon: "assets/images/equipment/chapter2/ch2_weapon_spear.png",
        helmet: "assets/images/equipment/chapter2/ch2_armor_sentinel_helmet.png",
        armor: "assets/images/equipment/chapter2/ch2_armor_sentinel_armor.png",
        shoes: "assets/images/equipment/chapter2/ch2_armor_sentinel_boots.png",
      },
      descriptions: {
        3: "3세트: 방어력 +8%",
        4: "4세트: 몬스터 공격 게이지 -8%",
      },
    },
    shadow: {
      oldName: "Shadow",
      setName: "도적 세트",
      weaponType: "dagger",
      weaponName: "단검",
      pieceNames: {
        helmet: "도적 두건",
        armor: "도적 가죽갑옷",
        shoes: "도적 장화",
      },
      images: {
        weapon: "assets/images/equipment/chapter2/ch2_weapon_dagger.png",
        helmet: "assets/images/equipment/chapter2/ch2_armor_vanguard_helmet.png",
        armor: "assets/images/equipment/chapter2/ch2_armor_vanguard_armor.png",
        shoes: "assets/images/equipment/chapter2/ch2_armor_vanguard_boots.png",
      },
      descriptions: {
        3: "3세트: 민첩 +8%",
        4: "4세트: 공격 필요 거리 -8%",
      },
    },
    colossus: {
      oldName: "Colossus",
      setName: "견습기사 세트",
      weaponType: "greatsword",
      weaponName: "대검",
      pieceNames: {
        helmet: "견습기사 투구",
        armor: "견습기사 갑옷",
        shoes: "견습기사 장화",
      },
      images: {
        weapon: "assets/images/equipment/chapter2/ch2_weapon_colossus.png",
        helmet: "assets/images/equipment/chapter2/ch2_armor_colossus_helmet.png",
        armor: "assets/images/equipment/chapter2/ch2_armor_colossus_armor.png",
        shoes: "assets/images/equipment/chapter2/ch2_armor_colossus_boots.png",
      },
      descriptions: {
        3: "3세트: 공격력 +8%",
        4: "4세트: 보스 피해 +10%",
      },
    },
  }

  const inferSetKey = (template) => {
    const current = String(template.get("set_key") || "")
    if (sets[current]) return current

    const name = String(template.get("name") || "")
    for (const [setKey, set] of Object.entries(sets)) {
      if (name.includes(set.oldName) || name.includes(set.setName.replace(" 세트", ""))) {
        return setKey
      }
    }
    return ""
  }

  const inferPieceType = (template, set) => {
    const current = String(template.get("set_piece_type") || "")
    if (current) return current

    const equipmentSlot = String(template.get("equipment_slot") || "")
    const name = String(template.get("name") || "")
    if (equipmentSlot === "sword" || name.endsWith(set.weaponName)) return "weapon"
    if (equipmentSlot === "helmet" || name.endsWith("Helm") || name.includes("투구")) return "helmet"
    if (equipmentSlot === "armor" || name.endsWith("Armor") || name.includes("갑옷")) return "armor"
    if (equipmentSlot === "shoes" || name.endsWith("Boots") || name.includes("장화")) return "shoes"
    return equipmentSlot
  }

  const templates = app.findRecordsByFilter("item_templates", `item_type="equipment"`, "", 500, 0)
  for (const template of templates) {
    const setKey = inferSetKey(template)
    const set = sets[setKey]
    if (!set) continue

    const pieceType = inferPieceType(template, set)
    const rarity = String(template.get("rarity") || "")
    const rarityLabel = rarityLabels[rarity] || ""
    const itemBaseName = pieceType === "weapon" ? set.weaponName : set.pieceNames[pieceType]
    const imagePath = set.images[pieceType] || ""
    if (!itemBaseName || !imagePath) continue

    template.set("name", rarityLabel ? `${rarityLabel} ${itemBaseName}` : itemBaseName)
    template.set("description", `${set.setName} ${itemBaseName}.`)
    template.set("set_key", setKey)
    template.set("set_piece_type", pieceType)
    template.set("weapon_type", pieceType === "weapon" ? set.weaponType : "")
    template.set("image_path", imagePath)
    app.save(template)
  }

  let bonuses = []
  try {
    bonuses = app.findRecordsByFilter("equipment_set_bonuses", `is_active=true`, "", 100, 0)
  } catch (_) {
    bonuses = []
  }

  for (const bonus of bonuses) {
    const setKey = String(bonus.get("set_key") || "")
    const set = sets[setKey]
    if (!set) continue

    const requiredCount = Number(bonus.get("required_count") || 0)
    bonus.set("set_name", set.setName)
    if (set.descriptions[requiredCount]) {
      bonus.set("description", set.descriptions[requiredCount])
    }
    app.save(bonus)
  }
}, (app) => {
  // Keep localized chapter 2 equipment names on rollback.
})
