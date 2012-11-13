_       = require 'underscore'
mongodb = require 'mongodb'


# TODO: Remove start from exports =>
# Run start in check client with passing cb to getCollection =>
# DO refactoring of depending logic
start = (cb) =>
  server = new mongodb.Server "127.0.0.1", 27017, {}
  new mongodb.Db('test', server, {}).open (err, client) =>
    console.log "Setting up db client"
    if err
      cb err if cb
      return
    DBUtils.setClient client
    cb null if cb


#  Example of using db module
#start (err) =>
#  return if err
#  tataCollection = new ImgCollection "tata-collection"
#  nataCollection = new ImgCollection "nata-collection"
#  image1 = new Image "name1", "url1"
#  image2 = new Image "name2", "url2"
#  tataCollection.addImage image1, (err) =>
#    return if err
#    tataCollection.addImage image2, (err) =>
#      return if err
#      nataCollection.addImage image1, (err) =>
#        return if err
#        tataCollection.save (err) =>
#          return if err?
#          nataCollection.save (err) =>
#            return if err?
#            ImgCollection.getImgCollections (err, imgCollections) =>
#              console.log "Collections (#{imgCollections.length}):"
#              console.log collection.name for collection in imgCollections unless err?
#              imgCollections[0].remove (err) =>
#                return if err?
#                ImgCollection.getImgCollections (err, imgCollections) =>
#                  console.log "Collections (#{imgCollections.length}):"
#                  console.log collection.name for collection in imgCollections unless err?


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
    console.log "Getting collection '#{collectionName}'"
    new mongodb.Collection @client, collectionName

  @refreshCollection: (collectionName) ->
    @checkClient()
    console.log "Refreshing collection '#{collectionName}'"
    @getCollection collectionName

  @dropCollection: (collectionName, cb) ->
    @checkClient()
    console.log "Dropping collection '#{collectionName}'"
    @getCollection(collectionName).drop (err, collection) =>
      if err?
        console.log "Cannot drop collection '#{collectionName}': #{err.message}"
      else
        console.log "Collection '#{collectionName}' was successfully dropped"
      cb err, collection if cb?


class ImgCollection
  _id  : null
  name : null
  description : null
  dbCollection: null
  images : []
  loaded   : false

  constructor: (@name, @description) ->

  getDBCollection: ->
    if @dbCollection?
      @dbCollection
    else
      @dbCollection = DBUtils.getCollection @name

  toJSON: ->
    name        : @name
    description : @description

  isPersisted: -> @_id?

  insert: (cb) ->
    DBUtils.getCollectionsHolder().insert  @toJSON(), safe: true, (err, objects) =>
      if err?
        console.log "Cannot insert collection '#{@name}' to collection list: #{err.message}"
      else
        console.log "Collection '#{@name}' was successfully inserted to collection list"
        @_id = objects[0]._id
      cb err, objects[0] if cb?
    @

  update: (cb) ->
    DBUtils.getCollectionsHolder().update {_id: @_id}, @toJSON(), {},
      (err, updatedCollection) =>
        if err
          console.log "Cannot save collection '#{@name}': #{err.message}"
        else
          console.log "Collection '#{@name}' was successfully saved"
        cb err, updatedCollection if cb?
    @

  save: (cb) ->
    if @isPersisted()
      @update cb
    else
      @insert cb
    @

  remove: (cb) ->
    console.log "Remove collection '#{@name}' from db"
    if !@_id?
      console.log "Cannot remove collection '#{@name}'. There is no _id field"
      cb new Error("There is no _id field") if cb?
    else
      @getDBCollection().drop (err) =>
        if err?
          console.log "Cannot remove collection '#{@name}' images: #{err.message}"
          cb err if cb?
        else
          console.log "Collection '#{@name}' images were successfully removed"
          DBUtils.getCollectionsHolder().remove _id : @_id, (err) =>
            if err?
              console.log "Cannot remove collection '#{@name}' data from collections holder"
              cb err if cb?
            else
              console.log "Collection '#{@name}' was fully removed from db"
              cb null if cb?
    @

  addImage: (image, cb) ->
    @images.push image
    image.insertTo @, cb
    @

  removeImage: (image, cb) ->
    @images = _.filter @images, (img) => img == image
    image.removeFrom @, cb
    @

  clone: (imgCollection) ->
    _.extend @, imgCollection

  getCollectionImages: (cb) ->
    console.log "Getting collection '#{@name}' images"
    @getDBCollection().find().toArray (err, objects) =>
      @loaded = !err?
      if err?
        console.log "Cannot get collection '#{@name}' images: #{err.message}"
      else
        console.log "Collection '#{@name}' images were successfully loaded"
        @images = _.map objects, (object) => (new Image).clone(object)
      cb err, @images if cb?
    @

  @collections: []
  @collectionsNum : null

  @areAllCollectionsLoaded: ->
    @collections.length == @collectionsNum && _.all @collections, (collection) => collection.loaded

  @getImgCollections: (cb) ->
    console.log "Getting list of image collections"
    DBUtils.getCollectionsHolder().find().toArray (err, objects) =>
      if err?
        console.log "Cannot get list of image collections: #{err.message}"
      else
        console.log "List of image collections (#{objects.length}) successfully received"

        @collections = []
        @collectionsNum = objects.length

        _.each objects, (object) =>
          newImgCollection = (new ImgCollection).clone(object)
          newImgCollection.getCollectionImages (err) =>
            @collections.push newImgCollection
            if @areAllCollectionsLoaded()
              cb null, @collections if cb?

class Image
  name     : null
  imageURL : null
  thumbURL : null
  date     : Date.now()

  constructor: (@name, @imageURL, @thumbURL, date) ->
    @date = date if date?

  toJSON: ->
    imageURL  : @imageURL
    thumbURL  : @thumbURL
    name      : @name
    date      : @date

  insertTo: (collection, cb) ->
    collection.getDBCollection().insert @toJSON(), safe: true, (err, objects) =>
      if err
        console.log "Cannot insert image '#{@name}' " +
                    "to collection '#{collection.name}': #{err.message}"
      else
        @._id = objects[0]._id
        console.log "Image '#{@name}' was successfully inserted " +
                    "to collection '#{collection.name}' with _id=#{@._id}"
      cb err, objects if cb?
    @

  removeFrom: (collection, cb) ->
    collection.getDBCollection().remove _id: @_id, (err, result) =>
      if err?
        console.log "Cannot remove image '#{@name}' " +
                    "from collection '#{collection.name}': #{err.message}"
      else
        console.log "Image '#{@name}' was successfully removed " +
                    "from collection '#{collection.name}'"
      cb err, result if cb?
    @

  clone: (image) ->
    _.extend @, image


exports.start         = start
exports.ImgCollection = ImgCollection
exports.Image         = Image
exports.DBUtils       = DBUtils