_       = require 'underscore'
mongodb = require 'mongodb'
log     = require './server-logger.coffee'

host = '127.0.0.1'
port = 27017
dbName = 'production'
logger = log.logger

setHost = (value) -> host = value
setPort = (value) -> port = value
setDBName = (value) -> dbName = value
setLogger = (value) -> logger = value

# TODO: Remove start from exports =>
# Run start in check client with passing cb to getCollection =>
# Do refactoring of depending logic
start = (cb) =>
  if DBUtils.client
    cb null if cb
    return
  server = new mongodb.Server host, port, {}
  new mongodb.Db(dbName, server, {safe: true}).open (err, client) =>
    logger.debug "Setting up db client"
    if err
      cb err if cb
      return
    DBUtils.setClient client
    cb null if cb


class DBUtils
  @client : null
  @collectionsHolderName :"imgCollections"

  @setClient: (client) -> @client = client

  @checkClient: -> throw new Error("Client of DBUtils is not set") unless @client?

  @getCollectionsHolder: ->
    @getCollection @collectionsHolderName

  @getCollection: (collectionName) ->
    return null unless collectionName?
    @checkClient()
    logger.debug "Getting collection '#{collectionName}'"
    new mongodb.Collection @client, collectionName

  @refreshCollection: (collectionName) ->
    @checkClient()
    logger.debug "Refreshing collection '#{collectionName}'"
    @getCollection collectionName

  @dropCollection: (collectionName, cb) ->
    @checkClient()
    logger.debug "Dropping collection '#{collectionName}'"
    @getCollection(collectionName).drop (err, collection) =>
      if err?
        logger.debug "Cannot drop collection '#{collectionName}': #{err.message}"
      else
        logger.debug "Collection '#{collectionName}' was successfully dropped"
      cb err, collection if cb?


class ImgCollection

  constructor: (@name, @type, @description ) ->
    @_id          = null
    @images       = []
    @date         = Date.now()

  isEmpty: () -> @images.length == 0

  toJSON: ->
    name        : @name
    description : @description
    date        : @date
    type        : @type
    images      : _.map(@images, (image) -> image.toJSON())

  isPersisted: -> @_id?

  insert: (cb) ->
    DBUtils.getCollectionsHolder().insert  @toJSON(), safe: true, (err, objects) =>
      if err?
        logger.debug "Cannot insert collection '#{@name}' to collection list: #{err.message}"
        cb err if cb
      else
        logger.debug "Collection '#{@name}' was successfully inserted to collection list"
        @_id = objects[0]._id
        cb err, objects[0] if cb?
    @

  update: (cb) ->
    DBUtils.getCollectionsHolder().update {_id: @_id}, @toJSON(), {},
      (err, updatedCollection) =>
        if err
          logger.debug "Cannot save collection '#{@name}': #{err.message}"
        else
          logger.debug "Collection '#{@name}' was successfully saved"
        cb err, updatedCollection if cb?
    @

  save: (cb) ->
    if @isPersisted()
      @update cb
    else
      ImgCollection.addCollection @
      @insert cb
    @

  remove: (cb) ->
    logger.debug "Remove collection '#{@name}' from db"
    DBUtils.getCollectionsHolder().remove _id : @_id, (err) =>
      if err?
        logger.debug "Cannot remove collection '#{@name}' data from collections holder"
        cb err if cb?
      else
        logger.debug "Collection '#{@name}' was fully removed from db"
        ImgCollection.removeCollection @
        cb null if cb?
    @

  addImage: (image, cb) ->
    logger.debug "Add image '#{image.name}' to collection '#{@name}'"
    @images.push image
    @update cb
    @

  removeImage: (image, cb) ->
    logger.debug "Remove image '#{image.name}' from collection '#{@name}'"
    @images = _.filter @images, (i) -> i.imageURL != image.imageURL
    if @isEmpty()
      @remove cb
    else
      @update cb
    @

  clone: (imgCollection) ->
    _.extend @, imgCollection

  @collections: []

  @addCollection: (collection) ->
    @collections.push collection

  @removeCollection: (collection) ->
    @collections = _.filter @collections, (c) => c != collection

  @getImgCollections: (cb) ->
    logger.debug "Getting list of image collections"
    DBUtils.getCollectionsHolder().find().toArray (err, objects) =>
      if err?
        logger.debug "Cannot get list of image collections: #{err.message}"
        cb err if cb
      else
        logger.debug "List of image collections (#{objects.length}) successfully received"
        @collections = _.map objects, (object) ->
          object.images = _.map object.images, (i) -> (new Image).clone i
          (new ImgCollection).clone(object)
        cb null, @collections if cb

class Image

  constructor: (@name, @imageURL, @thumbURL, date) ->
    @date = if date? then date else Date.now()

  toJSON: ->
    imageURL  : @imageURL
    thumbURL  : @thumbURL
    name      : @name
    date      : @date

  clone: (image) ->
    _.extend @, image


exports.setHost = setHost
exports.setPort = setPort
exports.setDBName = setDBName
exports.setLogger = setLogger

exports.start         = start
exports.ImgCollection = ImgCollection
exports.Image         = Image
exports.DBUtils       = DBUtils
