should = require('chai').Should()
async = require('async')
Client = require('request-json').JsonClient
app = require('../server')

client = new Client("http://localhost:7000/")


# connection to DB for "hand work"
cradle = require 'cradle'
connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database('cozy')


# helpers

# Function for async to create and index notes
createNoteFunction = (title, content) ->
    (callback) ->
        note =
            title: title
            content: content
            docType: "Note"

        client.post "data/", note, (error, response, body) ->
            client.post "data/index/#{body._id}",
                fields: ["title", "content"]
                , callback


describe "Indexation", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            console.log 'DB destroyed'
            db.create ->
                console.log 'DB recreated'
                done()

    # Start application before starting tests.
    before (done) ->
        app.listen(8888)
        done()



    describe "indexing and searching", ->
        it "Given I index four notes", (done) ->
            async.series [
                createNoteFunction "Note 01", "little stories begin"
                createNoteFunction "Note 02", "great dragons are coming"
                createNoteFunction "Note 03", "small hobbits are afraid"
                createNoteFunction "Note 04", "such as humans"
            ], ->
                done()
            
        it "When I send a request to search the notes containing dragons", (done) ->
            client.post "data/search/note", { query: "dragons" }, \
                    (error, response, body) =>
                @result = body
                done()

        it "Then result is the second note I created", ->
            @result.rows.length.should.equal 1
            @result.rows[0].title.should.equal "Note 02"
            @result.rows[0].content.should.equal "great dragons are coming"

    describe "Fail indexing", ->

        it "When I index a document that does not exist", (done) ->
            client.post "data/index/923", \
                    { fields: ["title", "content"] }, (error, response, body) =>
                @response = response
                done()

            it "Then it returns a 404 error", ->
                @response.statusCode.should.equal 404

