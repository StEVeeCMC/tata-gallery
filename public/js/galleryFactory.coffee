$ ($) ->
  type = getCollectionType()
  $.get '/struct', (collections) ->
    (appendNextCollection = (collections) ->
      return if collections.length is 0
      collection = collections.pop()
      if collection.type is type
        imagesCollection = []
        collection.images.forEach (image) ->
          imagesCollection.push
            dataLarge       : 'img/all/' + image.imageURL
            dataThumb       : 'img/all/thumbs/' + image.thumbURL
            collectionName  : collection.name
            fileName        : image.imageURL
        $content = $ 'div.content'
        $rgGallery = $('#rg-gallery-tmpl').tmpl(
          description: collection.description
          imagesCollection:imagesCollection
        ).appendTo $content
        $rgGallery.bind "firstImageIsReady", () ->
          appendNextCollection collections
        createNewGallery $rgGallery, collection, isAdmin
      else
        appendNextCollection collections
    )(collections)