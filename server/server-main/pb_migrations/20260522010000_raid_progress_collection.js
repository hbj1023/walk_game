migrate((app) => {
  try {
    app.findCollectionByNameOrId("raid_progress")
  } catch (_) {
    const collection = {
      "id": "pbc_2201000000",
      "listRule": null,
      "viewRule": null,
      "createRule": null,
      "updateRule": null,
      "deleteRule": null,
      "name": "raid_progress",
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
          "id": "relation2201000001",
          "maxSelect": 1,
          "minSelect": 0,
          "name": "raid",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "relation"
        },
        {
          "hidden": false,
          "id": "number2201000002",
          "max": null,
          "min": 0,
          "name": "monster_current_hp",
          "onlyInt": false,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number2201000003",
          "max": null,
          "min": 0,
          "name": "total_distance_accumulated_m",
          "onlyInt": false,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number2201000004",
          "max": null,
          "min": 0,
          "name": "distance_since_last_attack_cycle_m",
          "onlyInt": false,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number2201000005",
          "max": null,
          "min": 0,
          "name": "distance_since_last_monster_attack_m",
          "onlyInt": false,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number2201000006",
          "max": null,
          "min": 0,
          "name": "total_attack_cycles",
          "onlyInt": true,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number2201000007",
          "max": null,
          "min": 0,
          "name": "total_monster_attack_cycles",
          "onlyInt": true,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "select2201000008",
          "maxSelect": 1,
          "name": "status",
          "presentable": false,
          "required": false,
          "system": false,
          "type": "select",
          "values": [
            "waiting",
            "in_progress",
            "cleared",
            "failed",
            "canceled"
          ]
        },
        {
          "hidden": false,
          "id": "date2201000009",
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
          "id": "date2201000010",
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

    collection.fields.find((field) => field.name === "raid").collectionId = app.findCollectionByNameOrId("raids").id
    app.importCollections([collection], false)
  }

  const progress = app.findCollectionByNameOrId("raid_progress")
  progress.listRule = "@request.auth.id != ''"
  progress.viewRule = "@request.auth.id != ''"
  progress.createRule = "@request.auth.id != ''"
  progress.updateRule = "@request.auth.id != ''"
  app.save(progress)
}, (app) => {
  try {
    const collection = app.findCollectionByNameOrId("raid_progress")
    app.delete(collection)
  } catch (_) {}
})
