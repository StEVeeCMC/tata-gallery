_               = require 'underscore'
http            = require 'http'
express         = require 'express'
params          = require 'express-params'
passport        = require 'passport'
LocalStrategy   = require('passport-local').Strategy
flash           = require 'connect-flash'
log4js          = require 'log4js'

db              = require './server-db.coffee'
auth            = require './server-auth'
imgProcessing   = require './server-img-process'
log             = require './server-logger.coffee'

app             = express()
server          = http.createServer app
port            = 8080
uploadDir       = __dirname + '/tmp/'
logger          = log.logger

passport.serializeUser (user, done) => done null, user._id

passport.deserializeUser (id, done) => auth.findById id, (err, user) => done(err, user)

# Use the LocalStrategy within Passport.
# Strategies in passport require a `verify` function, which accept
# credentials (in this case, a username and password), and invoke a callback
# with a user object.  In the real world, this would query a database;
# however, in this example we are using a baked-in set of users.
passport.use new LocalStrategy (username, password, done) =>
  # asynchronous verification, for effect...
  process.nextTick () =>
    # Find the user by username.  If there is no user with the given
    # username, or the password is not correct, set the user to `false` to
    # indicate failure and set a flash message.  Otherwise, return the
    # authenticated `user`.
    auth.findByUsername username, (err, user) =>
      logger.debug "Searching user by username '#{username}' and password '#{password}'"
      return done(err) if err?
      return done(null, false, { message:'Unknown user ' + username }) unless user?
      return done(null, false, { message:'Invalid password' }) if user.password != password
      return done(null, user)


params.extend app


app.configure () =>
#  app.use log4js.connectLogger(logger, level: log4js.levels.DEBUG)
  app.use express.bodyParser(uploadDir: uploadDir)
  app.use express.cookieParser()
  app.use express.session(secret: 'tata-server')
  app.use express.methodOverride()
  app.use flash()
# Initialize Passport!  Also use passport.session() middleware, to support
# persistent login sessions (recommended).
  app.use passport.initialize()
  app.use passport.session()
  app.use app.router
  app.use express.static(__dirname + '/../public')


app.get '/login', (req, res) =>
  res.send
    user: req.user
    message: req.flash('error')


# POST /login
# Use passport.authenticate() as route middleware to authenticate the
# request.  If authentication fails, the user will be redirected back to the
# login page.  Otherwise, the primary route function function will be called,
# which, in this example, will redirect the user to the home page.
# curl -v -d "username=[username]&password=[password]" http://[ip]:[port]/login
app.post '/login', (req, res, next) =>
  passport.authenticate( 'local', (err, user, info) =>
    return next(err) if err
    return res.send(401) unless user
    req.logIn user, (err) =>
      return next(err) if err
      return res.redirect('/')
  )(req, res, next)


app.get '/logout', (req, res) =>
  req.logout()
  res.redirect('/')


# Simple route middleware to ensure user is authenticated.
# Use this route middleware on any resource that needs to be protected.  If
# the request is authenticated (typically via a persistent login session),
# the request will proceed.  Otherwise, the user will be redirected to the
# login page.
ensureAuthenticated = (req, res, next) =>
  return next() if req.isAuthenticated()
  res.redirect('/login')


dateSuffix = () =>
  today = new Date()
  (today.toDateString() + " " + today.toTimeString().slice(0, 8)).replace(/[ ]/g, "-")

defaultCollectionName = () => "collection-" + dateSuffix()

#TODO: Win/Linix hack => Use regular expressions
getFileNameByPath = (path) => path.split('/').map((w) => w.split("\\")).pop().pop()

getAllCollections = () => db.ImgCollection.collections


app.post '/upload', (request, response, next) =>
  logger.debug "Upload Request is called."
  if !request.user
    logger.debug 'WARNING! There are no rights to upload images'
    return

  collectionName = request.param 'name'
  collectionType = request.param 'type'
  unless collectionName && collectionName.length
    collection = new db.ImgCollection defaultCollectionName(), collectionType
  else
    collection = _.find getAllCollections(), (c) => c.name == collectionName
    return response.end() unless collection

  unless Array.isArray request.files.upload
    request.files.upload = [request.files.upload]

  files = request.files.upload
  filesNumber = files.length
  files.forEach (uploadedFile) =>
    return logger.debug "WARNING: uploaded file has no name" unless uploadedFile.name && uploadedFile.name.length
    fileURL = getFileNameByPath uploadedFile.path
    imgProcessing.saveFile uploadedFile, fileURL, (err) =>
      unless err
        image = new db.Image uploadedFile.name, fileURL, fileURL
        collection.addImage image
      if !(--filesNumber)
        collection.save () => response.end()


getCollectionByName = (name) ->
  if name && name.length
    collection = _.find getAllCollections(), (collection) => collection.name == name
  else
    new Error "Cannot find collection by empty name"

getCollectionImageByURL = (collection, imageURL) ->
  if imageURL and imageURL.length
    if collection
      image = _.find collection.images, (image) => image.imageURL == imageURL
    else
      new Error "Cannot find image in empty collection"
  else
    new Error "Cannot find image by emtpy url"


app.get '/remove/:collectionName/:imageURL', (request, response) =>
  if !request.user
    logger.debug "WARNING! There are no rights to remove an image!"
    return

  collectionName = request.params.collectionName
  imageURL = request.params.imageURL
  logger.debug 'Get request to remove image "%s" from collection "%s"', imageURL, collectionName

  try
    collection = getCollectionByName collectionName
    image = getCollectionImageByURL collection, imageURL
    return "Collection or image were not found" unless collection and image
    logger.debug "Collection and image were successfully found"
  catch err
    logger.debug err.message
    return response.end()

  collection.removeImage image, (err) =>
    return response.end() if err
    logger.debug "Image '#{image.imageURL}' (#{image.name}) was successfully removed"
    imgProcessing.removeImage image.imageURL
    imgProcessing.removeThumb image.thumbURL
    response.end()


app.get '/struct', (request, response) =>
  logger.debug 'Get collections list request'
  for collection in getAllCollections()
    logger.debug "+ #{collection.name} (#{collection.images.length})"
    for image in collection.images
      logger.debug "|  #{image.imageURL}"
  result = []
  for collection in getAllCollections()
    result.push collection.toJSON()
  response.send result


app.post '/collectionDescription', (request, response) =>
  newCollectionDescription = request.body.description
  collectionName = request.body.collectionName
  logger.debug "Get request to change collection '#{collectionName}' description to '#{newCollectionDescription}'"
  try
    collection = getCollectionByName collectionName
    return response.end() unless collection
    logger.debug "Collection '#{collectionName}' was successfully found"
  catch err
    logger.debug "There was error during collection search: #{err.message}"
    return response.end()
  collection.description = newCollectionDescription
  collection.save()
  response.end()


app.post '/collectionType', (request, response) =>
  collectionName = request.body.collectionName
  newCollectionType = request.body.type
  logger.debug "Get request to change collection '#{collectionName}' type to '#{newCollectionType}'"
  try
    collection = getCollectionByName collectionName
    return response.end() unless collection
    logger.debug "Collection '#{collectionName}' was successfully found"
  catch err
    logger.debug "There was error during collection search: #{err.message}"
    return response.end()
  collection.type = newCollectionType
  collection.save()
  response.end()


app.post '/up', (request, response) ->
  if !request.user
    logger.debug "WARNING! There are no rights to remove an image!"
    return

  collectionName = request.body.collectionName
  imageURL = request.body.imageURL
  logger.debug 'Get request to up image "%s" in collection "%s"', imageURL, collectionName

  try
    collection = getCollectionByName collectionName
    images = collection.images
    image = _.find images, (image) -> imageURL == image.imageURL
    index = images.indexOf image
    prevIndex = if index == 0 then index else index - 1
    images[index] = images[prevIndex]
    images[prevIndex] = image
  catch err
    logger.debug "There was error during image up: #{err.message}"
    return response.end()

  collection.save()
  response.end()


app.post '/down', (request, response) ->
  if !request.user
    logger.debug "WARNING! There are no rights to remove an image!"
    return

  collectionName = request.body.collectionName
  imageURL = request.body.imageURL
  logger.debug 'Get request to down image "%s" in collection "%s"', imageURL, collectionName

  try
    collection = getCollectionByName collectionName
    images = collection.images
    image = _.find images, (image) -> imageURL == image.imageURL
    index = images.indexOf image
    nextIndex = if index == images.length - 1 then index else index + 1
    images[index] = images[nextIndex]
    images[nextIndex] = image
  catch err
    logger.debug "There was error during image down: #{err.message}"
    return response.end()

  collection.save()
  response.end()


#  TODO: Prepare log, upload and other dependent dirs
db.setLogger logger
db.start (err) =>
  return logger.debug "Error: #{err.message}" if err
  db.ImgCollection.getImgCollections (err) =>
    return logger.debug "Error: #{err.message}" if err
    server.listen(port)

