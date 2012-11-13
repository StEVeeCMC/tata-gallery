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
    thumbQuality = 100
    gm(file.path).thumb thumbSide, thumbSide, thumbPath, thumbQuality, (err) =>
      #       .crop(sideMin, sideMin, (width - sideMin) / 2, (height - sideMin) / 2)
      if err
        logger.debug err.message
        cb err if cb
        return

      logger.debug('Full view image "%s" was successfully thumbed', file.name)
      cb null if cb


saveFile = (file, fileName, cb) =>
  fs.exists file.path, (isExists) =>
    if isExists
      fs.readFile file.path, (err, data) =>
        fullPath = collectionsDir + fileName
        thumbPath = thumbsDir + fileName
        thumbSide = 400

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
      cb new Error "Cannot save file: file '#{file.path}' not found" if cb


removeFile = (rootDir, imageType, imageName) =>
  path = rootDir + imageName
  if fs.existsSync path
    fs.unlink path, (err) =>
      if (err != null)
        logger.debug "Cannot remove file '#{imageName}': #{err.message}"
        return
      logger.debug('%s file "%s" was successfully removed from collection "%s"', imageType, imageName)


removeImage = (imageName) =>
  removeFile collectionsDir, "Image", imageName


removeThumb = (imageName) =>
  removeFile thumbsDir, "Thumb", imageName


exports.collectionsDir = collectionsDir
exports.thumbsDir = thumbsDir

exports.removeImage = removeImage
exports.removeThumb = removeThumb
exports.makeThumbnail = makeThumbnail
exports.saveFile = saveFile