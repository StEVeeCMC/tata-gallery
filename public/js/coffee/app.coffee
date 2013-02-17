require.config
  paths:
    'admin.controller'    : 'admin-controller'
    'gallery.factory'     : 'gallery-factory'
    'jquery'              : 'lib/jquery-1.9.1.min'
    'jquery.ui'           : 'lib/jquery-ui'
    'jquery.tmpl'         : 'lib/jquery.tmpl.min'
    'jquery.easing'       : 'lib/jquery.easing.1.3'
    'jquery.elastislide'  : 'lib/jquery.elastislide'

require [
  'jquery'
  'gallery.factory'
  'admin.controller'
], ($, gallleryFactory, adminController) ->
  $ () ->
    adminController.activateAdminControls()
    galleryFactory.createGallery()