migrate((app) => {
  const collection = {
    "id": "pbc_1142497001",
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "name": "item_templates",
    "type": "base",
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210256",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": "^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1579384326",
        "max": 0,
        "min": 0,
        "name": "name",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "select1156453330",
        "maxSelect": 1,
        "name": "item_type",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "equipment",
          "consumable"
        ]
      },
      {
        "hidden": false,
        "id": "select2525688161",
        "maxSelect": 1,
        "name": "equipment_slot",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "helmet",
          "armor",
          "shoes"
        ]
      },
      {
        "hidden": false,
        "id": "select3082862150",
        "maxSelect": 1,
        "name": "rarity",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "common",
          "rare",
          "epic",
          "legendary",
          "mythic"
        ]
      },
      {
        "hidden": false,
        "id": "number4077315460",
        "max": null,
        "min": 0,
        "name": "recover_hp",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number1789278845",
        "max": null,
        "min": 0,
        "name": "base_hp",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number799061330",
        "max": null,
        "min": 0,
        "name": "base_attack",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number4020456465",
        "max": null,
        "min": 0,
        "name": "base_defense",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number1359267563",
        "max": null,
        "min": 0,
        "name": "base_agility",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number434354159",
        "max": null,
        "min": 1,
        "name": "max_stack_quantity",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number674981351",
        "max": null,
        "min": 0,
        "name": "price_coin",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1843675174",
        "max": 0,
        "min": 0,
        "name": "description",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "bool458715613",
        "name": "is_active",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "bool"
      },
      {
        "hidden": false,
        "id": "autodate2990389176",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "presentable": false,
        "system": false,
        "type": "autodate"
      },
      {
        "hidden": false,
        "id": "autodate3332085495",
        "name": "updated",
        "onCreate": true,
        "onUpdate": true,
        "presentable": false,
        "system": false,
        "type": "autodate"
      }
    ],
    "indexes": [],
    "system": false
  }

  try {
    app.findCollectionByNameOrId(collection.name)
    return
  } catch (_) {}

  app.importCollections([collection], false)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
