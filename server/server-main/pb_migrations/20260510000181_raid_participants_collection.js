migrate((app) => {
  const collection = {
    "id": "pbc_4143557897",
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "name": "raid_participants",
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
        "collectionId": "pbc_2188842165",
        "hidden": false,
        "id": "relation1468490675",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "raid",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "relation"
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
        "id": "number885192135",
        "max": null,
        "min": 0,
        "name": "contribution_damage",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number2390758621",
        "max": null,
        "min": 0,
        "name": "contribution_distance_m",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number875753986",
        "max": null,
        "min": 0,
        "name": "contribution_attack_count",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "select3555653690",
        "maxSelect": 1,
        "name": "join_status",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "joined",
          "cleared",
          "left",
          "kicked"
        ]
      },
      {
        "hidden": false,
        "id": "date2745685176",
        "max": "",
        "min": "",
        "name": "joined_at",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "date"
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

  collection.fields.find((field) => field.name === "raid").collectionId = app.findCollectionByNameOrId("raids").id
  collection.fields.find((field) => field.name === "character").collectionId = app.findCollectionByNameOrId("characters").id

  app.importCollections([collection], false)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
