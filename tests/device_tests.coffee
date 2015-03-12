should = require('chai').Should()
fs = require 'fs'
helpers = require './helpers'

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

client = helpers.getClient()
client.setBasicAuth "proxy", "token"

describe "Device", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        db.save '321', value: "val", done

    before helpers.startApp
    after helpers.stopApp

    deviceID = null

    describe "Add a device", ->

        it "When I post a device", (done) ->
            setTimeout () =>
                client.post "device/", login: "work", (err, res, body) =>
                    console.log err if err
                    @response = res
                    deviceID = body.id
                    done()
            , 1000

        it "Then I got a 200 response", ->
            @response.statusCode.should.equal 200

    describe "Try to add a similar device", ->

        it "When I post a device", (done) ->
            client.post "device/", login: "work", (err, res, body) =>
                console.log err if err
                @response = res
                @body = body
                done()

        it "Then I got a 400 response", ->
            @response.statusCode.should.equal 400

        it "Add I got a error message correct", ->
            @body.msg = "This default filter doesn't exist"


    describe "Remove an existing device", ->

        it "When I post a device", (done) ->
            client.post "device/", login: "phone", (err, res, body) =>
                console.log err if err
                @response = res
                deviceID = body.id
                done()

        it "Then I got a 200 response", ->
            @response.statusCode.should.equal 200

        it "And I remove a device", (done) ->
            client.del "device/#{deviceID}/", (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "And I got a 404 response", ->
            @response.statusCode.should.equal 404

    describe "Try to add a device without name", ->

        it "When I tryy to post a device", (done) ->
            client.post "device/", {}, (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a 400 response", ->
            @response.statusCode.should.equal 400