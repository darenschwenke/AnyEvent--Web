(function($) {

    $('.btnUndo').on('click', function(e){
        e.preventDefault()
        console.log("UNDO")
        Builder.undo()
    })

    $('.btn-choose-color').on('mouseover', function(e){
        console.log('Color selector mouseover')
        if (_browser.isTouch()) {
            console.log('Disable mouseover event for touchscreens')
            return false
        }
        $('.colorpicker').show();
        return false
    });

    $('.btn-choose-color').on('click', function(e){
        console.log('Color selector click')        
        $('.colorpicker').toggle();
        return false
    });

    $('.colorpicker').on('click', 'a', function(){
        var color = $(this).data('color').toString()
        $('.colorpicker').hide()
        Builder.setBrickColor(color)
        return false;
    });

    $('.btn-rotate').on('click', function() {
        Builder.rotateBrick(-1)
    })

    $('.colorpicker').on('mouseleave', function(){
        $('.colorpicker').hide();
    });

    $('.btn-remove').click(function(){
       if ($(this).hasClass('active')) {
           Builder.setMode(0);
       } else {
           Builder.setMode(1);
       }
        return false;
    });

    $('.brick-selector a').click(function(){
        $('.brick-selector a').removeClass('active');
        $(this).addClass('active');
        $('.bricks svg').hide();
        if ($(this).attr('href').match(/original/)) {
            $('#original-bricks').show();
        } else {
            $('#special-bricks').show();
        }
        return false;
    });

    $('.bottom-container .info').on('click', function() {
        $('.info-shortcuts').toggle();
    });

    $('.rotate .builder-rotator a').click(function(){
        var rot = $(this).data('rotate');
        if (typeof rot == "undefined") { return false; }
        Builder.setPredefinedRotation(rot);
        return false;
    });
    $('.zoom .zoomin').on('click', function() {
        Builder.zoom(1)
        return false
    })
    $('.zoom .zoomout').on('click', function() {
        Builder.zoom(-1)
        return false
    })

    //var rot_center = [26,24]; // x, y
    function rotate_free (e) {
        var controller = $('.rotate .builder-rotator') ;
        var mouseX = e.pageX;
        var mouseY = e.pageY;
        var controllerX = controller.offset().left + controller.outerWidth()/2;
        var controllerY = controller.offset().top + controller.outerHeight()/2;

        var degrees = (Math.round(180/Math.PI * Math.atan2((mouseY-controllerY),(mouseX-controllerX)))+180+360) % 360;

        //Builder.setPredefinedRotation(degrees);
        Builder.setRotation(degrees);
    }

    $('.rotate-free').on('mousedown.rotate', function(e){
        $(document).on('mousemove.rotate', rotate_free);
        $(document).on('mouseup.rotate', function(e){
            $(document).off('mousemove.rotate');
            $(document).off('mouseup.rotate');
            return false;
        });
        return false;
    });

    $('.btn-publish-my-build').click(function(){
        if (_fl)
            _fl.track('chrom322', 'Chrom--6')
        if ($('.popup.publish, .popup.success').length > 0) { return false; }
        if (!Builder.save()) {
            new Popup({content: '<h2>' + _('builder_popup_wait') + '</h2><p>' + _('builder_popup_please_publish') + '</p>', submitLabel: _('notifications_okay'), hideCancel: true})
            return false;
        }
        if (window.isBanned) {
            new Popup({content: '<h2>'+_('notifications_attention')+'</h2>'+
                            '<p>'+_('notifications_inappropriate_behavior_1')+'</p>'+
                            '<p>'+_('notifications_inappropriate_behavior_2')+'</p>'+
                            '<p>'+_('notifications_inappropriate_behavior_3')+'</p>',
                        submitLabel: _('notifications_okay'), hideCancel: true})
            return false
        }
        publishBuild(Builder.getId());
        return false;
    });

    $('.main-header .login-button').click(function(e){
        e.preventDefault()

        Builder.save(function() {
            window.onbeforeunload = null
            window.location = '/login?return_url=/builder?load='+Builder.getId()+'&publish=false'
        })
    })

    $('footer.google-menu').hide() //Hide the footer in builder

    $(document).ready(function(){
        $('#main .container').addClass('builder');
        updateBrickCount()
    });

    $(document).on('click', '.bricks svg polygon', function(e) {
        $('svg polygon').attr('opacity', 0);
        $(this).attr('opacity', '0.4');
        
        $('.btn-rotate-ui').toggleClass('disabled', ($(this).data('rotateable') == '0'))
        
        var size = $(this).data('brick-size')
        var special = $(this).data('brick-special')
        if (size) {
            Builder.setBrickSize.apply(Builder, size)
        }
        if (special) {
            Builder.setSpecialBrick(special)
        }
    })

})(jQuery);


var _user = new User();
var hasbeenzero = false;
function updateBrickCount (count) {
    var maxBricks = 3000;
    var bricksLeft = maxBricks - count;
    if (bricksLeft < 0) {
        bricksLeft = 0;
    }
    var percentage = Math.round((count/maxBricks)*100);
    var meter = $('.brick-counter .meter__fill');
    meter.css('width', (100-percentage)+'%');
    console.log(bricksLeft + ' Bricks left')
    $('.brick-counter').data('tooltip', bricksLeft + ' ' + _('builder_bricks_remaining'));
    if (percentage > 79) {
        meter.css('backgroundColor', '#cf3b13');
    } else {
        meter.css('backgroundColor', '#60c958');
    }
    
    if ((maxBricks - count) < 1) {
        $('.brick-counter').trigger('mouseover');
        hasbeenzero = true;
    } else {
        if (hasbeenzero){
            $('.brick-counter').trigger('mouseout');
        }
    }
    
}


$('.level a').click(function() {
    var level = $(this).siblings().length - $(this).index();
    $('.level a').removeClass('active');
    $(this).addClass('active');
    Builder.setCameraFocus(level);
    return false;
})

window.onbeforeunload = function() { 
    return _('system_alert_2')
}



var publish_thumbnail,
    canvas_map,
    build_lat, build_lng,
    params = {},
    enable_start_animation = true,
    startColor,
    preloadHero = [];

function startBuilder (config) {
    var id = config.id,
        x = config.x,
        y = config.y,
        lat = config.lat,
        lon = config.lon,
        zoom = config.zoom,
        load = config.load,
        plate_id = config.plate_id,
        build_area = config.build_area,
        callback = config.callback,
        preloadSelectorImages = []

    window.location.hash = "#pos=" + x + "x" + y + "&load="+id;
    $('.btn-cancel').attr('href', $('.btn-cancel').attr('href') + '#3d=true&pos=' + x + "x" + y);
    build_lat = lat;
    build_lng = lon;
    console.log("Build will be created on x:" + x + " y: " + y + " Lat: " + build_lat+" Lng: "+build_lng);
    console.log("Build Id: " + id );

    console.log("Build area:")
    console.log(build_area)
    if (build_area) {
        $('.colorpicker').empty()
        
        $.each(build_area.brick_set, function(i, e) {
            var cls = isNaN(parseInt(e[0])) ? e[0] : 'c' + e[0]
            $('.colorpicker').append('<a data-color="'+e[0]+'" class="ir '+cls+'">Choose '+e[1]+'</a>')
        })
        
        if (build_area.popup_msg) {
            console.log(build_area.popup_msg)
            // Check if the message exists in the translations array
            var msg = build_area.popup_msg;
            if (window.translations.hasOwnProperty(build_area.popup_msg)) {
                console.log("Show msg from translations")
                msg = _('easter_egg_header_1') + ' ' +
                      _(build_area.popup_msg) + ' ' +
                      _('easter_egg_header_2')
            } else {
                console.log("Show raw msg")
            }
            new Popup({content: '<h3>'+msg+'</h3><p>' + _('easter_egg_body') + '</p>', hideCancel: true, submitLabel: _('easter_egg_btn')})
        }
    }

    startColor = $('.colorpicker a').eq(1).data('color')
    console.log('start color')
    console.log(startColor)

    $('.colorpicker a').each(function() {
        preloadSelectorImages.push('/' + window._version + '/img/build/bricks/all/'+$(this).data('color')+'.png')
    })

    console.log(preloadSelectorImages)

    utils.preloadImages(preloadSelectorImages);

    // Load the baseplate from the tile
    var mapimg = new Image();
    mapimg.src = "/api/maps/proxy/legoify?pegs=0&tileX="+x+"&tileY="+y+"&zoomLevel="+zoom;

    mapimg.onload = function () {
        canvas_map = document.createElement( 'canvas' );
        canvas_map.width = 32;
        canvas_map.height = 32;
        var context = canvas_map.getContext( '2d' );
        context.drawImage(mapimg, 0,0,32,32);
        if (load) {
            Builder.ready.add(function() {
                Builder.load(Builder.loadUrl());
            })
            if (callback) {
                Builder.loadReady.add(callback);
            }
        } else if (callback) {
            console.log('Adding callback');
            Builder.ready.add(callback);
        }
        Builder.init(canvas_map, id, x, y, zoom, plate_id, enable_start_animation, startColor);

        setTimeout(function() {
            utils.preloadImages(preloadHero)
        }, 1000)

        if (window.isBanned) {
            new Popup({content: '<h2>'+_('notifications_attention')+'</h2>'+
                            '<p>'+_('notifications_inappropriate_behavior_1')+'</p>'+
                            '<p>'+_('notifications_inappropriate_behavior_2')+'</p>'+
                            '<p>'+_('notifications_inappropriate_behavior_3')+'</p>',
                        submitLabel: _('notifications_okay'), hideCancel: true})
            return false
        }
    };
}

// Get a tile to build on
if (build = window.location.href.match('load=([^&#]+)')) {
    var build = build[1]
    console.log('url: '+window.location.href)
    if (window.location.href.match('publish=true')) {
        console.log('Go to publish!')
        enable_start_animation = false;
        var callback = function() {
            setTimeout(function(){
                publishBuildWithoutSnapshot(Builder.getId());
            },200);
        };
    } else {
        var callback = false;
    }

    console.log("Ladda build: "+build);
    console.log("Callback: "+callback);
    $.get('/api/builds/'+build, {}, function(d){
        console.log(d)
        startBuilder({
            id: build,
            x: d.build.location.tileX,
            y: d.build.location.tileY,
            lat: d.build.location.lat,
            lon: d.build.location.lon,
            zoom: 20,
            load: true,
            plate_id: d.build.buildNumber,
            build_area: d.build.build_area,
            callback: callback
        });
    },'json');

} else {

    if (pos = window.location.hash.match(/pos=(\d+)x(\d+)/)) {
        params['tileX'] = parseInt(pos[1]);
        params['tileY'] = parseInt(pos[2]);

        if (window.location.hash.match(/exactTile=true/)) {
            params['exactTile'] = 1;
        }
    }

    $.post('/api/builds', params, function(d){
        console.log(d)
        startBuilder({
            id: d.buildId,
            x: d.location.tileX,
            y: d.location.tileY,
            lat: d.location.lat,
            lon: d.location.lon,
            zoom: d.location.zoomLevel,
            load: false,
            plate_id: d.buildNumber,
            build_area: d.build_area,
        });
    });
}

function init_geocoder () {
    // Get the location and the map of the build
    var geocoder = new google.maps.Geocoder();
    var buildPos = new google.maps.LatLng(build_lat, build_lng);
    if (buildPos.lat() && buildPos.lng()) {
        geocoder.geocode({'latLng': buildPos}, function(results, status) {
            if (status == google.maps.GeocoderStatus.OK) {
                $('#location .address').html(results[0].formatted_address);
            } else {
                $('#location .address').html(buildPos.lat().toFixed(4) + ", " + buildPos.lng().toFixed(4));
                log("Geocode was not successful for the following reason: " + status);
            }
        });
    } else {
        setTimeout(init_geocoder, 500)
    }
}





