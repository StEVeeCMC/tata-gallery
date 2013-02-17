define [
  'gallery'
  'admin.controller'
  'jquery'
  'jquery.tmpl'
], (createGallery, adminController, $) ->
  class GalleryFactory

    constructor: (@contentHolder, @galleryTmpl, @galleryType) ->

    createGallery: () ->
      $.get '/struct', (collections) => @appendNextCollection collections
      @

    appendNextCollection: (collections) ->
        return if collections.length is 0
        collection = collections.pop()
        if collection.type is @galleryType

          imagesCollection = []
          collection.images.forEach (image) ->
            imagesCollection.push
              dataLarge       : 'img/all/' + image.imageURL
              dataThumb       : 'img/all/thumbs/' + image.thumbURL
              collectionName  : collection.name
              fileName        : image.imageURL

          $gallery = @galleryTmpl.tmpl(
            description       : collection.description
            imagesCollection  : imagesCollection
          ).appendTo @contentHolder

          $gallery.bind "firstImageIsReady", () =>
            @appendNextCollection collections

          createGallery $gallery, collection
        else
          @appendNextCollection collections

  unless window.galleryFactory
    window.galleryFactory =
      new GalleryFactory $('div.content'), $('#rg-gallery-tmpl'), adminController.getCollectionType()
  window.galleryFactory