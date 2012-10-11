function createNewGallery($rgGallery, isAdmin) {
    // ======================= Плагин imagesLoaded ===============================
    // https://github.com/desandro/imagesloaded

    // $('#my-container').imagesLoaded(myFunction)
    // выполняет возвратный вызов, когда все изображения загружены.
    // Нужно потому, что .load() не работает на кэшированных изображениях.

    // Возвратная функция получает коллекцию изображений как аргумент.

    $.fn.imagesLoaded = function (callback) {
        var $images = this.find('img'),
            len = $images.length,
            _this = this,
            blank = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';

        function triggerCallback() {
            callback.call(_this, $images);
        }

        function imgLoaded() {
            if (--len <= 0 && this.src !== blank) {
                setTimeout(triggerCallback);
                $images.unbind('load error', imgLoaded);
            }
        }

        if (!len) {
            triggerCallback();
        }

        $images.bind('load error', imgLoaded).each(function () {
            // Кэшированные изображения иногда не запускают загрузку, поэтому мы сбрасываем источник.
            if (this.complete || this.complete === undefined) {
                var src = this.src;
                // Хак для webkit ( http://groups.google.com/group/jquery-dev/browse_thread/thread/eee6ab7b2da50e1f)
                // Обход предупреждения webkit
                this.src = blank;
                this.src = src;
            }
        });

        return this;
    };

    // Контейнер галереи
    // Контейнер карусели
    var $esCarousel = $rgGallery.find('div.es-carousel-wrapper'),
        refreshNeeded = false,
    // Пункт карусели
        _$items = null,
        $items = function () {
            if (_$items == null || refreshNeeded) {
                _$items = $esCarousel.find('ul > li');
                refreshNeeded = false;
            }
            return _$items;
        },
    // Общее количество пунктов
        itemsCount = function() {
            return $items().length;
        };



        Gallery = (function () {
        // Индекс текущего пункта
        var current = 0,
        // Режим : карусель || во весь экран
            mode = 'carousel',
        // Проверка, если одно изображение загружено
            anim = false,
            collectionName = function () {
                return $items().eq(current).find('img').data('collectionname');
            },
            fileName = function () {
                return $items().eq(current).find('img').data('filename');
            },
            init = function () {

                // (Не обязательно) предварительная загрузка изображений здесь...
                $items().add('<img src="img/ajax-loader.gif"/><img src="img/black.png"/>').imagesLoaded(function () {
                    // Добавляем опции
                    _addViewModes();

                    // Добавляем обертку большого изображения
                    _addImageWrapper();

                    // Выводим первое изображение
                    _showImage($items().eq(current));
                });

                // Инициализуем карусель
                _initCarousel();

            },
            _initCarousel = function () {

                // Используем плагин elastislide:
                $esCarousel.show().elastislide({
                    imageW:100,
                    onClick:function ($item) {
                        if (anim) return false;
                        anim = true;
                        // По нажатию клавиши мыши выводим изображение
                        _showImage($item);
                        // Меняем текущее
                        current = $item.index();
                    }
                });

                // Устанавливаем текушее для elastislide
                $esCarousel.elastislide('setCurrent', current);

            },
            _addViewModes = function () {

                // Кнопки вверху справа: скрыть / показать карусель

                var $viewfull = $('<a class="view-control rg-view-full"></a>'),
                    $viewthumbs = $('<a class="view-control rg-view-thumbs rg-view-selected"></a>'),
                    $addControl = $('<a class="collection-control rg-view-add"></a>'),
                    $removeControl = $('<a class="collection-control rg-view-remove"></a>'),
                    $addFileForm = $(
                        '<form enctype="multipart/form-data" method="post">'+
                            '<input type="file" name="upload" multiple="multiple" class="file">'+
                            '<input type="text" name="name" class="file">'+
                        '</form>');


                $rgGallery.prepend($('<div class="rg-view"/>')
                    .append($viewfull)
                    .append($viewthumbs));

                if (isAdmin) {
                    $rgGallery.children().filter('div.rg-view')
                        .append($removeControl)
                        .append($addControl)
                        .append($addFileForm);

                    $addControl.bind('click.rgGallery', function (event) {
                        $fileInput = $addFileForm.find('input[type=file]');
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

                    $removeControl.bind('click.rgGallery', function (event) {
                        // Remove item
                        if (itemsCount() != 1) {
                            $.get('/remove/' + collectionName() + '/' + fileName());
                            $items().eq(current).remove();
                            refreshNeeded = true;
                            _navigate('left');
                        } else {
                            // There are no images so remove entire collection
                            $rgGallery.remove();
                        }
                    });
                }


                $viewfull.bind('click.rgGallery', function (event) {
                    $esCarousel.elastislide('destroy').hide();
                    $viewfull.addClass('rg-view-selected');
                    $viewthumbs.removeClass('rg-view-selected');
                    mode = 'fullview';
                    return false;
                });

                $viewthumbs.bind('click.rgGallery', function (event) {
                    _initCarousel();
                    $viewthumbs.addClass('rg-view-selected');
                    $viewfull.removeClass('rg-view-selected');
                    mode = 'carousel';
                    return false;
                });

            },
            _addImageWrapper = function () {

                // Добавляем структуру для больших изображений и кнопок навигации (если общее количество пунктов  > 1)

                $('#img-wrapper-tmpl').tmpl({itemsCount:itemsCount()}).appendTo($rgGallery);

                if (itemsCount() > 1) {
                    // Добавляем навигацию
                    var $navPrev = $rgGallery.find('a.rg-image-nav-prev'),
                        $navNext = $rgGallery.find('a.rg-image-nav-next'),
                        $imgWrapper = $rgGallery.find('div.rg-image');

                    $navPrev.bind('click.rgGallery', function (event) {
                        _navigate('left');
                        return false;
                    });

                    $navNext.bind('click.rgGallery', function (event) {
                        _navigate('right');
                        return false;
                    });

                    // Добавляем событие touchwipe для обертки большого изображения
                    $imgWrapper.touchwipe({
                        wipeLeft:function () {
                            _navigate('right');
                        },
                        wipeRight:function () {
                            _navigate('left');
                        },
                        preventDefaultEvents:false
                    });

                    $(document).bind('keyup.rgGallery', function (event) {
                        if (event.keyCode == 39)
                            _navigate('right');
                        else if (event.keyCode == 37)
                            _navigate('left');
                    });

                }

            },
            _navigate = function (dir) {

                // Навигация по большим изображениям

                if (anim) return false;
                anim = true;

                if (dir === 'right') {
                    if (current + 1 >= itemsCount())
                        current = 0;
                    else
                        ++current;
                }
                else if (dir === 'left') {
                    if (current - 1 < 0)
                        current = itemsCount() - 1;
                    else
                        --current;
                }

                _showImage($items().eq(current), current);

            },
            _showImage = function ($item, index) {

                // Выводим большое изображение, которое ассоциировано с $item

                var $loader = $rgGallery.find('div.rg-loading').show();

                $items().removeClass('selected');
                $item.addClass('selected');

                var $thumb = $item.find('img'),
                    largesrc = $thumb.data('large'),
                    title = $thumb.data('description'),
                    deatils = $thumb.data('details'),
                    $details = $('<div class="box"><div class="backdrop"></div><div class="details"></div></div></div>');


                $('<img/>').load(function () {

                    var $rgImage = $rgGallery.find('div.rg-image');
                    var currentHeight = $rgImage.height();
                    $rgImage.height(currentHeight);
                    $rgImage.empty();
                    $('<img src="' + largesrc + '"/>')
                        .load(function(){
                            $rgImage.height('');
                        })
                        .appendTo($rgImage);

                    if (title)
                        $rgGallery.find('div.rg-caption').show().children('p').empty().text(title);
                    if (deatils) {
                        $details.find('div.details').append(deatils);
                        $rgGallery.find('div.rg-image').append($details);
                        $rgGallery.find('div.rg-image > img').bind('load', function(){
                            var widthRGGallery = $rgGallery.width();
                            var heightRGGallery = $rgGallery.height();
                            var widthImage = $(this).width();
                            var heightImage = $(this).height();
                            $details.width(widthImage/2);
                            $details.height(heightImage);
                            $details.css('right', (widthRGGallery-widthImage)/2);
                        });
                    }

                    $loader.hide();

                    if (mode === 'carousel') {
                        $esCarousel.elastislide('reload');
                        $esCarousel.elastislide('setCurrent', current);
                    }

                    anim = false;

                }).attr('src', largesrc);

            };

        return { init:init };

    })();

    Gallery.init();
}