migrate((app) => {
  const collection = {
    "id": "pbc_24081843",
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "name": "reward_logs",
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
        "cascadeDelete": false,
        "collectionId": "pbc_3298390430",
        "hidden": false,
        "id": "relation2474291252",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "character",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "select2371146282",
        "maxSelect": 1,
        "name": "source_type",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "battle",
          "mission",
          "raid",
          "stage_first_clear",
          "admin"
        ]
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text2503744609",
        "max": 0,
        "min": 0,
        "name": "source_id",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "cascadeDelete": false,
        "collectionId": "pbc_1142497001",
        "hidden": false,
        "id": "relation2530802565",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "reward_item_template",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "number2655777328",
        "max": null,
        "min": 0,
        "name": "reward_item_quantity",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number1417152454",
        "max": null,
        "min": 0,
        "name": "reward_coin",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
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

  collection.fields.find((field) => field.name === "character").collectionId = app.findCollectionByNameOrId("characters").id
  collection.fields.find((field) => field.name === "reward_item_template").collectionId = app.findCollectionByNameOrId("item_templates").id

  app.importCollections([collection], false)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
