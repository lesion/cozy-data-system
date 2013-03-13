load 'application'

Client = require("request-json").JsonClient

Account = require '../../lib/account'
Crypt = require '../../lib/crypt'
User = require '../../lib/user'
randomString = require('../../lib/random').randomString


accountManager = new Account()
client = new Client("http://localhost:9102/")
crypt = new Crypt()
user = new User()
db = require('../../helpers/db_connect_helper').db_connect()
correctWitness = "Encryption is correct"


before 'get doc with witness', ->
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            send 404
        else if err
            console.log "[Get doc] err: #{err}"
            send 500
        else if doc?
            if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
                slaveKey = crypt.decrypt app.crypto.masterKey,
                    app.crypto.slaveKey
                if doc.witness?
                    try
                        witness = crypt.decrypt slaveKey, doc.witness
                        if witness is correctWitness
                            @doc = doc
                            next()
                        else
                            console.log "[Get doc] err: data are corrupted"
                            send 402
                    catch err
                        console.log "[Get doc] err: data are corrupted"
                        send 402
                else
                    witness = crypt.encrypt slaveKey, correctWitness
                    db.merge params.id, witness: witness, (err, res) =>
                        if err
                            # oops unexpected error !
                            console.log "[Merge] err: #{err}"
                            send 500
                        else
                            @doc = doc
                            next()
            else
                console.log "err : master key and slave key don't exist"
                send 500
        else
            send 404
, only: ['findAccount', 'updateAccount', 'mergeAccount']

before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            send 404
        else if err
            console.log "[Get doc] err: #{err}"
            send 500
        else if doc?
            @doc = doc
            next()
        else
            send 404
, only: ['deleteAccount']


# helpers
encryptPassword = (callback)->
    if @body.password
        if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
            slaveKey = crypt.decrypt app.crypto.masterKey, app.crypto.slaveKey
            newPwd = crypt.encrypt slaveKey, @body.password
            @body.password = newPwd
            @body.docType = "Account"
            witness = crypt.encrypt slaveKey, correctWitness
            @body.witness = witness
            callback true
        else
            callback false, new Error("master key and slave key don't exist")
    else
        callback false

toString = ->
    "[Account for model: #{@id}]"


toString = ->
    "[Account for model: #{@id}]"


#POST /accounts/password/
action 'initializeKeys', =>
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            send 500
        else
            app.crypto = {} if not app.crypto?
            if user.salt? and user.slaveKey?
                app.crypto.masterKey =
                    crypt.genHashWithSalt body.password, user.salt
                app.crypto.slaveKey = user.slaveKey
                send 200
                if app.crypto.masterKey.length isnt 32
                    console.log "[initializeKeys] err: password to initialize
                        keys is different than user password"
                    send 500
            else
                salt = crypt.genSalt(32 - body.password.length)
                masterKey = crypt.genHashWithSalt body.password, salt
                slaveKey = randomString()
                encryptedSlaveKey = crypt.encrypt masterKey, slaveKey
                app.crypto.masterKey = masterKey
                app.crypto.slaveKey  = encryptedSlaveKey
                data = salt: salt, slaveKey: encryptedSlaveKey
                db.merge user._id, data, (err, res) =>
                    if err
                        console.log "[initializeKeys] err: #{err}"
                        send 500
                    else
                        send 200


#PUT /accounts/password/
action 'updateKeys', ->
    if body.password?
        user.getUser (err, user) ->
            if err
                console.log "[updateKeys] err: #{err}"
                send 500
            else
                if app.crypto? and app.crypto.masterKey? and
                        app.crypto.slaveKey?
                    if app.crypto.masterKey.length isnt 32
                        console.log "[initializeKeys] err: password to
                            initialize keys is different than user password"
                        send 500
                    else
                        slaveKey = crypt.decrypt app.crypto.masterKey,
                                app.crypto.slaveKey
                        salt = crypt.genSalt(32 - body.password.length)
                        app.crypto.masterKey =
                            crypt.genHashWithSalt body.password, salt
                        app.crypto.slaveKey =
                            crypt.encrypt app.crypto.masterKey, slaveKey
                        data = slaveKey: app.crypto.slaveKey, salt: salt
                        db.merge user._id, data, (err, res) =>
                            if err
                                console.log "[updateKeys] err: #{err}"
                                send 500
                            else
                                send 200
                else
                    console.log "[updateKeys] err: masterKey and slaveKey don't\
                        exist"
                    send 500
    else
        send 500


#DELETE /accounts/reset/
action 'resetKeys', ->
    user.getUser (err, user) ->
        if err
            console.log "[updateKeys] err: #{err}"
            send 500
        else
            if app.crypto?
                app.crypto = null
            data = slaveKey: null, salt: null
            db.merge user._id, data, (err, res) =>
                if err
                    console.log "[resetKeys] err: #{err}"
                    send 500
                else
                    send 204


#DELETE /accounts/
action 'deleteKeys', ->
    if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
        app.crypto.masterKey = null
        app.crypto.slaveKey = null
        send 204
    else
        console.log "[deleteKeys] err: masterKey and slaveKey don't exist"
        send 500


#POST /account/
action 'createAccount', ->
    @body = body
    body.docType = "Account"
    body.toString = toString
    encryptPassword (pwdExist, err) ->
        if err
            console.log "[createAccount] err: #{err}"
            send 500
        else
            if pwdExist
                db.save @body, (err, res) ->
                    if err
                        railway.logger.write "[createAccount] err: #{err}"
                        send 500
                    else
                        send _id: res._id, 201
            else
                send 401


#GET /account/:id
action 'findAccount', ->
    delete @doc._rev # CouchDB specific, user don't need it
    if @doc.password?
        encryptedPwd = @doc.password
        slaveKey = crypt.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @doc.password = crypt.decrypt slaveKey, encryptedPwd
        @doc.toString = toString
        send @doc
    else
        send 500


#GET /account/exist/:id
action 'existAccount', ->
    db.head params.id, (err, res, status) ->
        if status is 200
            send {"exist": true}
        else if status is 404
            send {"exist": false}


#PUT /account/:id
action 'updateAccount', ->
    @body = body
    encryptPassword (pwdExist, err) ->
        if err
            console.log "[updateAccount] err: #{err}"
            send 500
        else
            if pwdExist
                db.save params.id, @body, (err, res) ->
                    if err
                        # oops unexpected error !
                        console.log "[updateAccount] err: #{err}"
                        send 500
                    else
                        send 200
            else
                send 401


#PUT /account/merge/:id
action 'mergeAccount', ->
    @body = body
    encryptPassword (pwdExist, err) ->
        if err
            console.log "[mergeAccount] err: #{err}"
            send 500
        else
            db.merge params.id, @body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Merge] err: #{err}"
                    send 500
                else
                    send 200


#PUT /account/upsert/:id
action 'upsertAccount', ->
    @body = body
    encryptPassword (pwdExist, err) ->
        if pwdExist and not err
            db.get params.id, (err, doc) ->
                db.save params.id, body, (err, res) ->
                    if err
                        # oops unexpected error !
                        console.log "[Upsert] err: #{err}"
                        send 500
                    else if doc
                        send 200
                    else
                        send {"_id": res.id}, 201
        else
            send 500


#DELETE /account/:id
action 'deleteAccount', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.remove params.id, @doc.rev, (err, res) ->
        if err
            # oops unexpected error !
            console.log "[DeleteAccount] err: #{err}"
            send 500
        else
            # Doc is removed from indexation
            client.del "index/#{params.id}/", (err, res, resbody) ->
                send 204


#DELETE /account/all
action 'deleteAllAccounts', ->

    deleteAccounts = (accounts, callback) =>
        if accounts.length > 0
            account = accounts.pop()
            id = account.value._id
            db.remove id, account.value._rev, (err, res) =>
                if err
                    callback err
                else
                    # Doc is removed from indexation
                    client.del "index/#{id}/", (err, res, resbody) =>
                        if err
                            callback err
                        else
                            deleteAccounts accounts, callback
        else
            callback()

    accountManager.getAccounts (err, accounts) ->
        if err
            send 500
        else
            deleteAccounts accounts, (err) =>
                if err
                    send 500
                else
                    send 204
