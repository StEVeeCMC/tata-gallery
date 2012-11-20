vows          = require 'vows'
assert        = require 'assert'
imgProcessing = require '../server-img-process'
fs            = require 'fs'

collectionsDir               = __dirname + '/all/'
thumbsDir                    = __dirname + '/all/thumbs/'
testFile                     =
  path : __dirname + '/test-image'
  name : 'test-image'

imgProcessing.setCollectinsDir collectionsDir
imgProcessing.setThumbsDir thumbsDir
imgProcessing.setLogger(debug : () =>)

vows.describe('Image/File processing'
).addBatch(
  'Saving file' :
    topic : imgProcessing.saveFile testFile, testFile.name, @callback
    'saved file should have the same name as input': (err) =>
      assert.ifError err
      assert.isTrue fs.existsSync(collectionsDir + testFile.name), "Collection image doesn't exist"
      assert.isTrue fs.existsSync(thumbsDir + testFile.name), "Thumb image doesn't exist"
).addBatch(
  'Removing full view image' :
    topic : imgProcessing.removeImage testFile.name, @callback
    'full view image should be removed' : (err) =>
      assert.ifError err
      assert.isFalse fs.existsSync(collectionsDir + testFile.name), "Collection image is still existing"
).addBatch(
  'Removing thumb image' :
    topic : imgProcessing.removeThumb testFile.name, @callback
    'thumb image should be removed' : (err) =>
      assert.ifError err
      assert.isFalse fs.existsSync(thumbsDir + testFile.name), "Thumb image is still existing"
).run()

