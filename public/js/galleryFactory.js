$(function($){
    var isAdmin = false;
    $.get('/login', function(data){
        if (!data.user) return;
        isAdmin = true;
        $('.admin-control').removeClass('admin-control');
        $('#login').hide();
        $('#logout').show();
    });
    $.get('/struct', function(collections) {
        appendNextCollection(collections);
        function appendNextCollection(collections) {
            if (collections.length == 0) return;
            var collection = collections.pop();
            var imagesCollection = [];
            collection.images.forEach(function(image) {
                imagesCollection.push({
                    dataLarge       : 'img/all/' + image.imageURL,
                    dataThumb       : 'img/all/thumbs/' + image.thumbURL,
                    collectionName  : collection.name,
                    fileName        : image.imageURL
                })
            });
            var $content = $('div.content');
            var $rgGallery = $('#rg-gallery-tmpl').tmpl({
                description: collection.description,
                imagesCollection:imagesCollection
            }).appendTo($content);
            $rgGallery.bind("firstImageIsReady", function(){
                appendNextCollection(collections);
            });
            createNewGallery($rgGallery, collection, isAdmin);
        }
    });
});