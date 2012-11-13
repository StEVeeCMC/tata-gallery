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


removeFile = (rootDir, imageType, collectionName, imageName) =>
  if fs.existsSync(rootDir + collectionName + '/' + imageName)
    fs.unlink rootDir + collectionName + '/' + imageName, (err) =>
      if (err != null)
        logger.debug "Cannot remove file '#{imageName}': #{err.message}"
        return

      logger.debug('%s "%s" was successfully removed from collection "%s"', imageType, imageName, collectionName)
      cFiles = fs.readdirSync(rootDir + collectionName)
      if cFiles.length == 0
        logger.debug '%s "%s" dir is empty. It is time to remove it', imageType, collectionName
        fs.rmdir rootDir + collectionName, (err) =>
          if err != null
            logger.debug "Cannot remove dir '#{collectionName}': #{err.message}"
            return
          logger.debug '%s "%s" dir was successfully removed', imageType, collectionName


removeImage = (collectionName, imageName) =>
  removeFile collectionsDir, "Image", collectionName, imageName


removeThumb = (collectionName, imageName) =>
  removeFile thumbsDir, "Thumb", collectionName, imageName


exports.collectionsDir = collectionsDir
exports.thumbsDir = thumbsDir

exports.removeImage = removeImage
exports.removeThumb = removeThumb
exports.makeThumbnail = makeThumbnail
exports.saveFile = saveFile