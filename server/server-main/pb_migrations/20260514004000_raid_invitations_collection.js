migrate((app) => {
  try {
    app.findCollectionByNameOrId("raid_invitations")
  } catch (_) {
    const collection = {
      "id": "pbc_3025147806",
      "listRule": null,
      "viewRule": null,
      "createRule": null,
      "updateRule": null,
      "deleteRule": null,
      "name": "raid_invitations",
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
          "id": "relation1744825497",
          "maxSelect": 1,
          "minSelect": 0,
          "name": "inviter_character",
          "presentable": false,
          "required": false,
          "system": false,
          "type": "relation"
        },
        {
          "cascadeDelete": false,
          "collectionId": "_pb_users_auth_",
          "hidden": false,
          "id": "relation2340726940",
          "maxSelect": 1,
          "minSelect": 0,
          "name": "invited_user",
          "presentable": false,
          "required": false,
          "system": false,
          "type": "relation"
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
            "pending",
            "accepted",
            "declined",
            "expired",
            "canceled"
          ]
        },
        {
          "hidden": false,
          "id": "date1297661659",
          "max": "",
          "min": "",
          "name": "invited_at",
          "presentable": false,
          "required": false,
          "system": false,
          "type": "date"
        },
        {
          "hidden": false,
          "id": "date2535835892",
          "max": "",
          "min": "",
          "name": "responded_at",
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
    collection.fields.find((field) => field.name === "inviter_character").collectionId = app.findCollectionByNameOrId("characters").id

    app.importCollections([collection], false)
  }

  const setRules = (collectionName, rules) => {
    const collection = app.findCollectionByNameOrId(collectionName)

    if (rules.list !== undefined) collection.listRule = rules.list
    if (rules.view !== undefined) collection.viewRule = rules.view
    if (rules.create !== undefined) collection.createRule = rules.create
    if (rules.update !== undefined) collection.updateRule = rules.update
    if (rules["delete"] !== undefined) collection.deleteRule = rules["delete"]

    app.save(collection)
  }

  const authenticated = "@request.auth.id != ''"
  const ownRaidHost = "host_character.user = @request.auth.id"
  const ownParticipant = "character.user = @request.auth.id"
  const canSeeInvitation = "invited_user = @request.auth.id || inviter_character.user = @request.auth.id"
  const canCreateInvitation = "inviter_character.user = @request.auth.id"
  const canUpdateInvitation = "invited_user = @request.auth.id"

  setRules("raids", { list: authenticated, view: authenticated, create: ownRaidHost })
  setRules("raid_participants", { list: authenticated, view: authenticated, create: ownParticipant })
  setRules("raid_invitations", {
    list: canSeeInvitation,
    view: canSeeInvitation,
    create: canCreateInvitation,
    update: canUpdateInvitation,
  })
  setRules("friendships", { list: authenticated, view: authenticated })
}, (app) => {
  for (const collectionName of ["raids", "raid_participants", "raid_invitations", "friendships"]) {
    try {
      const collection = app.findCollectionByNameOrId(collectionName)
      collection.listRule = null
      collection.viewRule = null
      collection.createRule = null
      collection.updateRule = null
      collection.deleteRule = null
      app.save(collection)
    } catch (_) {}
  }
})
