define([
    'admin.controller',
    'jquery',
    'jquery.easing',
    'jquery.elastislide'
], function(adminController, $){
    return createNewGallery = function ($rgGallery, collection) {
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

        var eventReadyName = "firstImageIsReady";
        var firstImageIsReady = false;
        // Контейнер галереи
        // Контейнер карусели
        var $esCarousel = $rgGallery.find('div.es-carousel-wrapper'),
        // Пункт карусели
            $items = function () {
                return $esCarousel.find('ul > li');
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
                        $viewthumbs = $('<a class="view-control rg-view-thumbs rg-view-selected"></a>');

                    $rgGallery.prepend($('<div class="rg-view"/>')
                        .append($viewfull)
                        .append($viewthumbs));

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

                    if (itemsCount() <= 1) $viewfull.click();

                    if (adminController.isAdmin) {
                        var $addControl    = $('<a class="collection-control rg-view-add"></a>'),
                            $removeControl = $('<a class="collection-control rg-view-remove"></a>'),
                            $addFileForm   = $(
                                '<form enctype="multipart/form-data" method="post">'+
                                    '<input type="file" name="upload" multiple="multiple" class="file">'+
                                    '<input type="text" name="name" class="file">'+
                                    '</form>'),
                            $descriptionControl = $('<a class="collection-control rg-view-change-description"></a>'),
                            $upControl = $('<a class="collection-control rg-view-up"></a>'),
                            $downControl = $('<a class="collection-control rg-view-down"></a>'),
                            $selectControl = $(
                                '<select>' +
                                    '<option value="inters">Интерьеры</option>' +
                                    '<option value="logos">Лого</option>' +
                                    '<option value="draws">Рисую</option>' +
                                    '</select>');

                        $selectControl.val(collection.type);

                        $rgGallery.children().filter('div.rg-view')
                            .append($removeControl)
                            .append($addControl)
                            .append($addFileForm)
                            .append($descriptionControl)
                            .append($downControl)
                            .append($upControl)
                            .append($selectControl);

                        $selectControl.change(function(event) {
                            adminController.changeType(collectionName(), $selectControl.val());
                        });

                        $upControl.bind('click.rgGallery', function (event) {
                            adminController.upImage(collectionName(), fileName());
                            if (current > 0) {
                                $items().eq(current).after($items().eq(current-1));
                                current--;
                            }
                        });

                        $downControl.bind('click.rgGallery', function (event) {
                            adminController.downImage(collectionName(), fileName());
                            if (current < $items().size()) {
                                $items().eq(current).before($items().eq(current+1));
                                current++;
                            }

                        });

                        $descriptionControl.bind('click.rgGallery', function (event) {
                            $collectionDescription = $rgGallery.children().filter("#collectionDescription");
                            var $dialogBox = $( "#descriptionDialog" ).tmpl();
                            $descriptionInput = $dialogBox.children().filter('#descriptionInput');
                            $descriptionInput.val(collection.description);
                            $dialogBox.dialog({
                                buttons:{
                                    Ok:function () {
                                        var _this = this;
                                        adminController.changeDescription(collectionName(), $descriptionInput.val(),
                                            function () {
                                                collection.description = $descriptionInput.val();
                                                $collectionDescription.html($descriptionInput.val());
                                                $(_this).dialog("close");
                                            });
                                    },
                                    Cancel:function () {
                                        $(this).dialog("close");
                                    }
                                }
                            });
                        });

                        $addControl.bind('click.rgGallery', function (event) {
                            var $fileInput = $addFileForm.find('input[type=file]');
                            $fileInput.val("");
                            $fileInput.change(function () {
                                $fileInput.unbind();
                                if ($fileInput.val() != "") {
                                    $addFileForm.find('input[name=name]').val(collectionName());
                                    adminController.uploadForm($addFileForm);
                                }
                            });
                            $fileInput.click();
                        });

                        $removeControl.bind('click.rgGallery', function (event) {
                            adminController.removeImage(collectionName(), fileName(), function(){
                                var isItLast = itemsCount() == 1;
                                $items().eq(current).remove();
                                if (isItLast) {
                                    // There are no images so remove entire collection
                                    $rgGallery.remove();
                                } else {
                                    // There are several images - just navigate to the left
                                    _navigate('left');
                                }
                            });
                        });
                    }



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

                        if (!firstImageIsReady) {
                            $rgGallery.trigger(eventReadyName);
                            firstImageIsReady = true;
                        }

                    }).attr('src', largesrc);

                };

            return { init:init };

        })();

        Gallery.init();
    }
});
