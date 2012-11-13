_               = require 'underscore'
http            = require 'http'
express         = require 'express'
params          = require 'express-params'
passport        = require 'passport'
LocalStrategy   = require('passport-local').Strategy
flash           = require 'connect-flash'
log4js          = require 'log4js'
crypto          = require 'crypto'

db              = require './server-db.coffee'
auth            = require './server-auth'
imgProcessing   = require './server-img-process'

app             = express()
server          = http.createServer app
port            = 8888

uploadDir       = __dirname + '/tmp/'

log4js.configure
  appenders: [
    {
      type: 'console'
      category: 'logFile'
    }
    {
      type: 'file'
      filename: './logs/server-tata.log4js.log'
      category: 'logFile'
      maxLogSize: 10*1024*1024*1024
      backups: 5
    }
  ]

logger = log4js.getLogger 'logFile'
logger.setLevel 'DEBUG'

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
    return next(err) if err?
    return res.send(401) unless user?
    req.logIn user, (err) =>
      return next(err) if err?
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

getFileURLHash = (fileName) => crypto.createHash('md5').update(fileName + dateSuffix()).digest("hex")

getAllCollections = () => db.ImgCollection.collections


app.post '/upload', (request, response, next) =>
  logger.debug "Upload Request is called."
  if !request.user
    logger.debug 'WARNING! There are no rights to upload images'
    return

  collectionName = request.param 'name'
  unless collectionName && collectionName.length
    collection = new db.ImgCollection defaultCollectionName()
  else
    collection = _.find getAllCollections(), (c) => c.name == collectionName
    return response.end() unless collection

  unless Array.isArray request.files.upload
    request.files.upload = [request.files.upload]

  files = request.files.upload
  filesNumber = files.length
  files.forEach (uploadedFile) =>
    return logger.debug "WARNING: uploaded file has no name" unless uploadedFile.name && uploadedFile.name.length
    fileURL = getFileURLHash uploadedFile.name
    imgProcessing.saveFile uploadedFile, fileURL, (err) =>
      unless err
        image = new db.Image uploadedFile.name, fileURL, fileURL
        collection.addImage image
      if !(--filesNumber)
        collection.save () => response.end()

app.get '/remove/:collectionName/:fileName', (request, response) =>
  if !request.user
    logger.debug "WARNING! There are no rights to remove an image!"
    return

  collectionName = request.params.collectionName
  imageURL = request.params.fileName
  if (collectionName + '').length == 0 || (imageURL + '').length == 0
    logger.error 'Collection name or file name is empty'
    return

  logger.debug 'Get request to remove image "%s" from collection "%s"', imageURL, collectionName

  collection = _.find getAllCollections(), (collection) => collection.name == collectionName
  return response.end() unless collection
  logger.debug "Collection '#{collectionName}' was found"

  image = _.find collection.images, (image) => image.imageURL == imageURL
  return response.end() unless image
  logger.debug "Image '#{imageURL}' was found"

  collection.removeImage image, (err) =>
    return response.end() if err
    logger.debug "Image '#{image.imageURL}' (#{image.name}) was successfully removed"
    imgProcessing.removeImage image.imageURL
    imgProcessing.removeThumb image.thumbURL

app.get '/struct', (request, response) =>
  logger.debug 'Get collections list request'
  result = {}
  for collection in getAllCollections()
    result[collection.name] = []
    logger.debug "+ #{collection.name} (#{collection.images.length})"
    for image in collection.images
      logger.debug "|  #{image.imageURL}"
      result[collection.name].push image.imageURL
  response.send result


db.start (err) =>
  return logger.debug "Error: #{err.message}" if err
  db.ImgCollection.getImgCollections (err) =>
    return logger.debug "Error: #{err.message}" if err
    server.listen(port)

