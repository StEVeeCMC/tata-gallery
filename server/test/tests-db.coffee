vows          = require 'vows'
assert        = require 'assert'
mongo         = require 'mongodb'
db            = require '../server-db.coffee'

db.setHost '127.0.0.1'
db.setPort 27017
db.setDBName 'test'

db.start () ->
  vows.describe('DB API testing'
  ).addBatch(
    'Get mongo collection' :
      topic : -> db.DBUtils.getCollection 'test-collection'
      'test description': (dbCollection) ->
        assert.instanceOf dbCollection, mongo.Collection
  ).run()

