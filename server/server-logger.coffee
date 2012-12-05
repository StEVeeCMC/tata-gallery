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

exports.logger = logger