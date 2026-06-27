migrate((app) => {
  const collection = {
    "id": "pbc_2712475614",
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "name": "equipment_slot_balances",
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
        "hidden": false,
        "id": "select1391984062",
        "maxSelect": 1,
        "name": "slot_type",
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
        "id": "select3221998915",
        "maxSelect": 1,
        "name": "main_stat",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "hp",
          "attack",
          "defense",
          "agility"
        ]
      },
      {
        "hidden": false,
        "id": "select120479968",
        "maxSelect": 1,
        "name": "sub_stat",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "hp",
          "attack",
          "defense",
          "agility"
        ]
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
