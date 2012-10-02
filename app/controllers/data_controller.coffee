load 'application'

db = require('../../helpers/db_connect_helper').db_connect()

# Welcome page
action "index", ->
    send "Cozy Data System", 200

# GET /data/exist/:id
action 'exist', ->
    db.head params.id, (err, res, status) ->
        if status is 200
            send {"exist": true}
        else if status is 404
            send {"exist": false}

# GET /data/:id
action 'find', ->
    db.get params.id, (err, doc) ->
        if err
            send 404
        else
            delete doc._rev # CouchDB specific, user don't need it
            send doc

# POST /data
# POST /data/:id
action 'create', ->
    if params.id
        db.get params.id, (err, doc) -> # this GET needed because of cache
            if doc
                send 409
            else
                db.save params.id, body, (err, res) ->
                    if err
                        send 409
                    else
                        send {"_id": res.id}, 201
    else
        db.save body, (err, res) ->
            if err
                # oops unexpected error !                
                console.log "[Create] err: " + JSON.stringify err
                send 500
            else
                send {"_id": res.id}, 201

# PUT /data/:id
action 'update', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        if doc
            db.save params.id, body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Update] err: " + JSON.stringify err
                    send 500
                else
                    send 200
        else
            send 404

# PUT /data/upsert/:id
action 'upsert', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        db.save params.id, body, (err, res) ->
            if err
                # oops unexpected error !
                console.log "[Upsert] err: " + JSON.stringify err
                send 500
            else if doc
                send 200
            else
                send {"_id": res.id}, 201

# DELETE /data/:id
action 'delete', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        if doc
            db.remove params.id, doc.rev, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Delete] err: " + JSON.stringify err
                    send 500
                else
                    send 204
        else
            send 404

# PUT /data/merge/:id
action 'merge', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        if doc
            db.merge params.id, body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Merge] err: " + JSON.stringify err
                    send 500
                else
                    send 200
        else
            send 404
