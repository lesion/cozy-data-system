fs = require "fs"
db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles

## Actions

# POST /data/:id/binaries
module.exports.add = (req, res, next) ->
    attach = (binary, name, file, doc) ->
        fileData =
            name: name
            "content-type": file.type
        stream = db.saveAttachment binary, fileData, (err, binDoc) ->
            if err
                console.log "[Attachment] err: " + JSON.stringify err
                deleteFiles req.files
                next()
                res.send 500, error: err.error
            else
                bin =
                    id: binDoc.id
                    rev: binDoc.rev
                if doc.binary
                    newBin = doc.binary
                else
                    newBin = {}

                newBin[name] = bin
                db.merge doc._id, binary: newBin, (err) ->
                    deleteFiles req.files
                    next()
                    res.send 201, success: true

        fs.createReadStream(file.path).pipe stream


    if req.files["file"]?
        file = req.files["file"]
        if req.body.name? then name = req.body.name else name = file.name
        if req.doc.binary?[name]?
            db.get req.doc.binary[name].id, (err, binary) ->
                attach binary, name, file, req.doc
        else
            binary =
                docType: "Binary"
            db.save binary, (err, binary) ->
                attach binary, name, file, req.doc
    else
        console.log "no doc for attachment"
        next()
        res.send 400, error: "No file send"


# GET /data/:id/binaries/:name/
module.exports.get = (req, res) ->
    name = req.params.name
    if req.doc.binary and req.doc.binary[name]

        stream = db.getAttachment req.doc.binary[name].id, name, (err) ->
            if err and err.error = "not_found"
                res.send 404, error: err.error
            else if err
                res.send 500, error: err.error
            else
                res.send 200

        if req.headers['range']?
            stream.setHeader 'range', req.headers['range']

        stream.pipe res

        res.on 'close', -> stream.abort()
    else
        res.send 404, error: 'not_found'

# DELETE /data/:id/binaries/:name
module.exports.remove = (req, res, next) ->
    name = req.params.name
    if req.doc.binary and req.doc.binary[name]
        id = req.doc.binary[name].id
        delete req.doc.binary[name]
        if req.doc.binary.length is 0
            delete req.doc.binary
        db.save req.doc, (err) ->
            db.get id, (err, binary) ->
                db.remove binary.id, binary.rev, (err) ->
                    next()
                    if err? and err.error = "not_found"
                        res.send 404, error: err.error
                    else if err
                        console.log "[Attachment] err: " + JSON.stringify err
                        res.send 500, error: err.error
                    else
                        res.send 204, success: true
    else
        next()
        res.send 404, error: 'not_found'

