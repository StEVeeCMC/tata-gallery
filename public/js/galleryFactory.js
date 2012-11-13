$(function($){
    var isAdmin = false;
    $.get('/login', function(data){
        if (!data.user) return;
        isAdmin = true;
        $('.admin-control').removeClass('admin-control');
        $('#login').hide();
        $('#logout').show();
    });
    $.get('/struct', function(structure){
        for (var collectionName in structure){
            var imagesCollection = [];
            var collection = structure[collectionName]
            for (var i=0; i<collection.length; i++){
                imagesCollection.push({
                    dataLarge       : 'img/all/'+collection[i],
                    dataThumb       : 'img/all/thumbs/'+collection[i],
                    collectionName  : collectionName,
                    fileName        : collection[i]
                })
            }
            var $content = $('div.content');
            var $rgGallery = $('#rg-gallery-tmpl').tmpl({imagesCollection:imagesCollection}).appendTo($content);
            createNewGallery($rgGallery, isAdmin);
        }
    });
});