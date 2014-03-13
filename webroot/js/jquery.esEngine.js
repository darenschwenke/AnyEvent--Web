/*
    This program is free for non commercial use under the GPL license.
    All code contained within is copyright daren.schwenke@gmail.com.
    Alternate licensing options are available.  For more information on
    obtaining a license, please contact daren.schwenke@gmail.com.
 
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>. 
*/
if(!window.console){ window.console = function(){}; }
var es;
var Engine = {
	init: function(options) {
		this.options = $.extend({},this.options,options);
		$(window).unload(function(){ es.destroy() });
		if ( this.options.autoconnect ) this.connect(this.options.url);
		return this;
	},
	connId: 0,
	options: {
		userName: '',
		userPassword: '',
		autoconnect: true
	},
	setOption: function(key,value) {
		this.options[key] = value;
	},
	reconnectPending: null,
	myonopen: function(){ $.esMsg({title:"Connection",message:"Connection established."}); es.send({eventName:'login',data: this.options } ) },
	myonclose: function(){ $.esMsg({title:"Connection Error",message:"Connection lost. Reconnecting.."});if ( ! es.reconnectPending ) es.reconnectPending = setTimeout(function() { es.connect() },500);},
	myonerror: function(e){if ( e ) $.esError({name:"Connection Error " + e.code,message:e.reason})},
	send: function(data) {
		if ( this.ws.readyState != 1 ) {
			$.esMsg({title:"Connection Error",message:"Not Connected."});
			return this;
		}
		return this.ws.send($.toJSON(data));
	},
	connect: function(url) {
		$.esMsg({title:"Connection",message:"Connecting..."});
		if ( this.reconnectPending ) clearTimeout(this.reconnectPending);
		this.reconnectPending = null;
		if ( ! url ) url = this.options.url;
		if ( this.ws ) {
			this.ws.close();
			this.ws = null;
		}
		this.ws = new WebSocket(url);
		if (!this.ws) {
			$.esError({name:"WebSocket Error",message:"Could not create a WebSocket connection\nPlease install a modern browser like Google Chrome."});
		} else {
			$(this.ws).bind('open', this.myonopen)
			.bind('close', this.myonclose)
			.bind('error', this.myonerror)
			.bind('message', function(e){
				try {
					var raw = $.evalJSON(e.originalEvent.data);
					if ( raw.data ) {
						var t = null;
						console.log(raw.data);
						if ( raw.data.length && typeof raw.data != 'string' ) {
							$.each(raw.data, function(i,m) {
								if ( m.t ) t = $(m.t);
								if ( m.e ) m.c = eval('(' + m.e + ')');
								if ( t && m.a ) t = t[m.a](m.c);
							});
						} else if ( raw.data.e || raw.data.c || raw.data.a ) {
							var m = raw.data;
							if ( m.t ) t = $(m.t);
							if ( m.e ) m.c = eval('(' + m.e + ')');
							if ( t && m.a ) t = t[m.a](m.c);
						}
					} else if ( raw.e || raw.c || raw.a ) {
							var m = raw;
							if ( m.t ) t = $(m.t);
							if ( m.e ) m.c = eval('(' + m.e + ')');
							if ( t && m.a ) t = t[m.a](m.c);
					} else {
						$.esError({name:"WebSocket Error", message: "Error parsing packet."});
						console.log(raw);
					}
				} catch(err) { 
					$.esError(err);
				}
			});
		}
	},
	destroy: function() {
		this.send({eventName:'disconnect'});
		this.ws.close();
		this.ws = null;
	} 
}
if (typeof Object.create !== 'function') {
    Object.create = function (o) {
        function F() {}
        F.prototype = o;
        return new F();
    };
}
(function($){
$.esEngine = function(options) {
	if ( ! es ) {
		es = Object.create(Engine);
		es.init(options);
	}
	return es;
}
$.esMsg = function (options) {
$("#messages").append('<b>' + options.title + "</b>&nbsp;&nbsp;" + options.message);
}
$.esError = function(err) {
	$.esMsg({title: err.name , message: err.message});
};

})(jQuery);
