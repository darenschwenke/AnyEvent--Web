var User = function(){
    var self = this
    this.token = false
    this.client_id = false
    this.channel_obj = false
    this.socket = false
    this.is_paused = false
    this.ongoing_build = null
    
    // Show that another user is building
    this.anotherDevice = function(ongoing_build, from_scratch) {
        if (self.is_paused) {
            return
        }
        self.ongoing_build = ongoing_build
        if (typeof from_scratch === 'undefined') {
            from_scratch = false
        }
        self.stopBuilding()
        self.showOngoingWarning()
    }

    this.showOngoingWarning = function(e) {
        var content = $('<div class="content">')
        if (window._browser.isMobile())
            content.append($('<img class="popup-img">').attr('src', '/img/v2/m/ongoing-fig.png'))
        content.append($('<h2>').html(_('notifications_attention')))
        content.append($('<p>').html(_('notifications_ongoing_build')))
        content.append($('<p>').html(_('notifications_continue')))

        new Popup({
            content: content,
            submitLabel: _('notifications_start_new_build'),
            ok_callback: self.start_new,
            cancelLabel: _('continue_building'),
            cancelClassMobile: 'btn-blue-gray',
            cancel_callback: self.continue_building,
            mobile: window._browser.isMobile(),
            mobile_remove: window._browser.isMobile()
        })
    };

    this.start_new = function(e) {
        $('.bg').remove()
        self.startBuilding(true)
        return false
    }

    this.continue_building = function(e) {
        var ongoing_build_url = '/api/builds/'+self.ongoing_build+'/data'
        console.log("Try to load the build "+ongoing_build_url)
        Builder.load(ongoing_build_url)
        $('.bg').remove()
        self.startBuilding(true)
        return false
    }

    // Notify the server that the user is currently building
    this.activeBuilderInterval = false
    this.activeBuilderIntervalRate = 20000
    
    this.startBuilding = function(override) {
        console.log("starting build")
        self.buildPoll(override)
        self.activeBuilderInterval = setInterval(self.buildPoll, self.activeBuilderIntervalRate)
        self.is_paused = false
    }
    this.stopBuilding = function(){
        console.log("stopping build")
        clearInterval(self.activeBuilderInterval)
        self.is_paused = true
    }
    this.buildPoll = function(override){
        if (typeof override === 'undefined') {
            override = false
        }
        $.post('/api/channel/active', {'build_id': Builder.getId(), 'override': override ? '1' : '0'}, function(response){
            if (response.build_id) {
                console.log("found another active session when polling")
                self.anotherDevice(response.build_id, true)
            }
        })
    }


    // Register the socket and listen to messages
    this.socketOnOpen = function(){
        console.log("Socket opened")
    }
    this.socketOnMessage = function(message){
        var data = JSON.parse(message.data)
        switch (data.status) {
            case 'ANOTHER_BUILDER':
                console.log("got a push with a different session")
                self.anotherDevice(data.build_id)
                break;
            case 'SAVE':
                console.log('Got push with save message.')
                Builder.save()
                break
            default: 
                console.log(data.status) 
                break
        }
    }
    this.socketOnError = function(error){
        console.log("Socket error")
        console.log(error.description)
    }
    this.socketOnClose = function(){
        console.log("Socket closed")
    }
    
    this.startListening = function(){
        if (typeof goog == "undefined") { alert("Failed to load jslib! Try reloading page.") }
        self.channel_obj = new goog.appengine.Channel(self.token)
        var handler = {
            onopen: self.socketOnOpen,
            onmessage: self.socketOnMessage,
            onerror: self.socketOnError,
            onclose: self.socketOnClose
        }
        self.socket = self.channel_obj.open(handler)
    }
    
    this.stopListening = function(){
        self.channel_obj = null
        self.socket = null
    }
    
    this.init = function(){
        console.log("Init channel")
        if (!_channel_token) {
            console.log("Missing channel token from backend! Set the _channel_token js-var.")
            return false
        }
        self.token = _channel_token
        self.startListening()
        self.startBuilding(false)
    }
    this.init()
}
