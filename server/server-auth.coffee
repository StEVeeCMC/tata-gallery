_   = require 'underscore'
db  = require './server-db'
log = require './server-logger.coffee'

logger = log.logger
users   = []

db.start (err) =>
  return if err
  db.DBUtils.getCollection('users').find().toArray (err, objects) =>
    return logger.debug err.message if err
    users = objects

findById = (id, fn) =>
  user = _.find users, (user) => user._id.toString() == id.toString()
  if user
    fn null, user
  else
    fn new Error "User with id '#{id}' does not exists"


findByUsername = (username, fn) =>
  for user in users
    return fn(null, user) if user.username == username
  fn(null, null)


exports.findById = findById
exports.findByUsername = findByUsername