function uploadForm($fileForm) {
    var formData = new FormData($fileForm[0]);
    $.ajax({
        url:'/upload', //server script to process data
        type:'POST',
        xhr:function () {  // custom xhr
            var myXhr = $.ajaxSettings.xhr();
            if (myXhr.upload) {
//                    check if upload property exists
//                        myXhr.upload.addEventListener('progress',progressHandlingFunction, false); // for handling the progress of the upload
            }
            return myXhr;
        },
        /*
         //Ajax events
         beforeSend: beforeSendHandler,
         success: completeHandler,
         error: errorHandler,
         */
        // Form data
        data:formData,
        //Options to tell JQuery not to process data or worry about content-type
        cache:false,
        contentType:false,
        processData:false
    });
}

$(function($){
    $addFileForm = $(
        '<form enctype="multipart/form-data" method="post">'+
            '<input type="file" name="upload" multiple="multiple" class="file">'+
            '<input type="text" name="name" class="file">'+
        '</form>');
    $('.footer').append($addFileForm);
    $('#new-collection-add').click(function(){
        var $fileInput = $addFileForm.find('input[type=file]');
        var $cNameInput = $addFileForm.find('input[name=name]');
        $fileInput.val("");
        $cNameInput.val("");
        $fileInput.change(function () {
            $fileInput.unbind();
            if ($fileInput.val() != "") {
                uploadForm($addFileForm);
            }
        });
        $fileInput.click();
    });

    $('.rg-gallery').each(function(){
        var $addControl    = $('<a class="collection-control rg-view-add"></a>'),
            $removeControl = $('<a class="collection-control rg-view-remove"></a>'),
            $addFileForm   = $(
                '<form enctype="multipart/form-data" method="post">'+
                    '<input type="file" name="upload" multiple="multiple" class="file">'+
                    '<input type="text" name="name" class="file">'+
                    '</form>');

        function collectionName(){

        };

        $(this).children().filter('div.rg-view')
            .append($removeControl)
            .append($addControl)
            .append($addFileForm);

        $addControl.bind('click.rgGallery', function (event) {
            var $fileInput = $addFileForm.find('input[type=file]');
            $fileInput.val("");
            $fileInput.change(function () {
                $fileInput.unbind();
                if ($fileInput.val() != "") {
                    $addFileForm.find('input[name=name]').val(collectionName());
                    var formData = new FormData($addFileForm[0]);
                    $.ajax({
                        url:'/upload', //server script to process data
                        type:'POST',
                        xhr:function () {  // custom xhr
                            var myXhr = $.ajaxSettings.xhr();
                            if (myXhr.upload) { // check if upload property exists
//                                        myXhr.upload.addEventListener('progress',progressHandlingFunction, false); // for handling the progress of the upload
                            }
                            return myXhr;
                        },
                        /*
                         //Ajax events
                         beforeSend: beforeSendHandler,
                         success: completeHandler,
                         error: errorHandler,
                         */
                        // Form data
                        data:formData,
                        //Options to tell JQuery not to process data or worry about content-type
                        cache:false,
                        contentType:false,
                        processData:false
                    });
                }
            });
            $fileInput.click();
        })
    })
});