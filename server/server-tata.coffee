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
  app.use log4js.connectLogger(logger, level: log4js.levels.DEBUG)
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


app.post '/upload', (request, response, next) =>
  logger.debug "Upload Request is called."
  if !request.user
    logger.debug 'WARNING! There are no rights to upload images'
    return

  collectionName = request.param 'name'
  unless collectionName && collectionName.length
    collectionName = defaultCollectionName()
    collection = new db.ImgCollection collectionName
  else
    collection = _.find collections, (collection) => collection.name == collectionName

  if Array.isArray request.files.upload
    processedCount = request.files.upload.length
    request.files.upload.forEach (file) =>
      fileName = crypto.createHash('md5').update(file.name + dateSuffix()).digest("hex")
      imgProcessing.saveFile file, fileName, (err) =>
        unless err
          image = new db.Image file.name, fileName, fileName
          collection.addImage image
        if !(--processedCount)
          collection.save () =>
            collections.push collection
            response.end()
  else
    file = request.files.upload
    fileName = crypto.createHash('md5').update(file.name + dateSuffix()).digest("hex")
    imgProcessing.saveFile file, fileName, (err) =>
      image = new db.Image file.name, fileName, fileName
      collection.addImage image, () =>
        collection.save () =>
          collections.push collection
          response.end()


app.get '/remove/:collectionName/:fileName', (request, response) =>
  if !request.user
    logger.debug "WARNING! There are no rights to remove an image!"
    return

  collectionName = request.params.collectionName
  imageName = request.params.fileName
  if (collectionName + '').length == 0 || (imageName + '').length == 0
    logger.error 'Collection name or file name is emprty'
    return
  logger.debug 'Get request to remove image "%s" from collection "%s"', imageName, collectionName
  imgProcessing.removeImage "", imageName
  imgProcessing.removeThumb "", imageName



app.get '/struct', (request, response) =>
  logger.debug 'Get collections list request'
#  response.send imgProcessing.getStructureSync()
  result = {}
  for collection in collections
    result[collection.name] = []
    for image in collection.images
      result[collection.name].push image.imageURL
  response.send result


collections = []
loadCollections = () =>
  db.ImgCollection.getImgCollections (err, imgCollections) =>
    return logger.debug err if err
    logger.debug "Collections (#{imgCollections.length}):"
    logger.debug collection.name for collection in imgCollections
    collections = imgCollections
    collection.getCollectionImages() for collection in imgCollections


db.start loadCollections
server.listen(port)

