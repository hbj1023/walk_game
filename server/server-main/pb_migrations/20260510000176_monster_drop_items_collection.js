migrate((app) => {
  const collection = {
    "id": "pbc_1491427763",
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "name": "monster_drop_items",
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
        "collectionId": "pbc_3786735569",
        "hidden": false,
        "id": "relation610191092",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "monster",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "relation"
      },
      {
        "cascadeDelete": false,
        "collectionId": "pbc_1142497001",
        "hidden": false,
        "id": "relation4218279752",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "item_template",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "number1002756889",
        "max": null,
        "min": 0,
        "name": "drop_rate",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number2124771343",
        "max": null,
        "min": 1,
        "name": "min_quantity",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number4007026917",
        "max": null,
        "min": 1,
        "name": "max_quantity",
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

  collection.fields.find((field) => field.name === "monster").collectionId = app.findCollectionByNameOrId("monsters").id
  collection.fields.find((field) => field.name === "item_template").collectionId = app.findCollectionByNameOrId("item_templates").id

  app.importCollections([collection], false)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
