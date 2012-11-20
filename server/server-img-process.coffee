gm              = require 'gm'
fs              = require 'fs'
log4js          = require 'log4js'

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

collectionsDir  = __dirname + '/../public/img/all/'
thumbsDir       = __dirname + '/../public/img/all/thumbs/'
thumbSide       = 100
thumbQuality    = 100

setCollectinsDir = (value) => collectionsDir = value
setThumbsDir = (value) => thumbsDir = value
setLogger = (value) => logger = value
setThumbSide = (value) => thumbSide = value
setThumbQuality = (value) => thumbQuality = value

makeThumbnail = (file, thumbPath, thumbSide, cb) =>
  logger.debug 'Thumbs full view image "%s"', file.name
  gm(file.path).size (err, value) =>
    if err
      logger.debug err.message
      cb err if cb
      return

    logger.debug 'Full view image "%s" dimensions: %d x %d', file.name, value.width, value.height
    width = value.width
    height = value.height
    sideMin = Math.min width, height

    gm(file.path).thumb thumbSide, thumbSide, thumbPath, thumbQuality, (err) =>
      #       .crop(sideMin, sideMin, (width - sideMin) / 2, (height - sideMin) / 2)
      if err
        logger.debug err.message
        cb err if cb
        return

      logger.debug('Full view image "%s" was successfully thumbed', file.name)
      cb null if cb


saveFile = (file, fileName, cb) =>
  fs.exists file.path, (exists) =>
    if exists
      fs.readFile file.path, (err, data) =>
        fullPath = collectionsDir + fileName
        thumbPath = thumbsDir + fileName

        #TODO: Use async methods
        fs.mkdirSync(collectionsDir) if !fs.existsSync(collectionsDir)
        fs.mkdirSync(thumbsDir) if !fs.existsSync(thumbsDir)

        logger.debug 'Creating full view image "%s"', file.name
        fs.writeFile fullPath, data, (err) =>
          if err != null
            logger.debug err.message
            cb err if cb
            return
          logger.debug 'Full view image "%s" was successfully created', file.name
          makeThumbnail file, thumbPath, thumbSide, cb
    else
      cb new Error "Cannot save file: file '#{fileName}' doesn't exist" if cb


removeFile = (fileDir, fileName, fileType, cb) =>
  logger.debug "Removing file '#{fileName}' from dir '#{fileDir}'"
  path = fileDir + fileName
  fs.exists path, (exists) =>
    if exists
      fs.unlink path, (err) =>
        if err != null
          logger.debug "Cannot remove file '#{fileName}': #{err.message}"
        else
          logger.debug('%s file "%s" was successfully removed from dir "%s"', fileType, fileName, fileDir)
        cb err if cb
    else
      cb new Error "Cannot remove file: file '#{fileName}' doesn't exist" if cb


removeImage = (imageName, cb) =>
  removeFile collectionsDir, imageName, "Image", cb


removeThumb = (imageName, cb) =>
  removeFile thumbsDir, imageName, "Thumb", cb


exports.collectionsDir = collectionsDir
exports.thumbsDir = thumbsDir

exports.setCollectinsDir = setCollectinsDir
exports.setThumbsDir = setThumbsDir
exports.setLogger = setLogger

exports.removeImage = removeImage
exports.removeThumb = removeThumb
exports.makeThumbnail = makeThumbnail
exports.saveFile = saveFile

