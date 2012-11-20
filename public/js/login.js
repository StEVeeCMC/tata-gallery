$(function($){
    $loginDialogBox = $('#loginDialog').tmpl();
    $('#login').click(function() {
        $loginDialogBox.find('.input-label > label').click(function(){
            $(this).siblings().filter('input').focus();
        });
        $loginDialogBox.find('.input-label > input').focusin(function(){
            $label = $(this).siblings().filter('label');
            $label.hide();
        });
        $loginDialogBox.find('.input-label > input').focusout(function(){
            $label = $(this).siblings().filter('label');
            if (!$(this).val()) $label.show();
        });
        $loginDialogBox.dialog({
            buttons : {
                Ok : function() {
                    var formData = new FormData();
                    formData.append('username', $('#username').val());
                    formData.append('password', $('#password').val());
                    $.ajax({
                        url: '/login',  //server script to process data
                        type: 'POST',
                        /*
                         //Ajax events
                         beforeSend: beforeSendHandler,
                         */
                        // Form data
                        data: formData,
                        error: function(){
                            $loginDialogBox.dialog( "widget").effect("shake", {times:3}, 333);
                        },
                        success: function(){
                            window.location.replace('/');
                        },
                        //Options to tell JQuery not to process data or worry about content-type
                        cache: false,
                        contentType: false,
                        processData: false
                    });
                },
                Cancel : function() {
                    $loginDialogBox.dialog("close");
                }
            }
        });
    });
});
