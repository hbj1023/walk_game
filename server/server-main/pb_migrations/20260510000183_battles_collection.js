migrate((app) => {
  const collection = {
    "id": "pbc_2885344579",
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "name": "battles",
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
        "cascadeDelete": false,
        "collectionId": "pbc_414258986",
        "hidden": false,
        "id": "relation3262944105",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "stage",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "relation"
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
        "hidden": false,
        "id": "select3686372543",
        "maxSelect": 1,
        "name": "battle_type",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "normal",
          "boss",
          "raid"
        ]
      },
      {
        "hidden": false,
        "id": "select2063623452",
        "maxSelect": 1,
        "name": "status",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "select",
        "values": [
          "in_progress",
          "win",
          "lose",
          "flee"
        ]
      },
      {
        "hidden": false,
        "id": "number3288281290",
        "max": null,
        "min": 0,
        "name": "distance_used_m",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number1584850441",
        "max": null,
        "min": 0,
        "name": "attack_count_used",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number4109690690",
        "max": null,
        "min": 0,
        "name": "total_damage_dealt",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number977346674",
        "max": null,
        "min": 0,
        "name": "total_damage_taken",
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
        "id": "date222754019",
        "max": "",
        "min": "",
        "name": "started_at",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "date"
      },
      {
        "hidden": false,
        "id": "date473765221",
        "max": "",
        "min": "",
        "name": "ended_at",
        "presentable": false,
        "required": false,
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

  collection.fields.find((field) => field.name === "character").collectionId = app.findCollectionByNameOrId("characters").id
  collection.fields.find((field) => field.name === "stage").collectionId = app.findCollectionByNameOrId("stages").id
  collection.fields.find((field) => field.name === "monster").collectionId = app.findCollectionByNameOrId("monsters").id
  collection.fields.find((field) => field.name === "raid").collectionId = app.findCollectionByNameOrId("raids").id

  app.importCollections([collection], false)
}, (app) => {
  // No-op: this migration may run against databases where the collection
  // already existed from an earlier schema import.
})
