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
(function($){
	$.extend({
		wse: function (opt) {
			var self;
			self = $.extend(this,{
				encoding: 'json',
				url: '',
				protocols: [],
				autoConnect: true,
				maxRetries: 10,
				readyState: WebSocket.CONNECTING,
				retryDelay: 1000,
				_reconnectPending: null,
				_retryCount: 0,
				_ws: null,
				encode: null,
				decode: null,
				onopen: function(e){console.log(e);},
				onclose: function(e){console.log(e);},
				onerror: function(e){console.log(e);},
				onmessage: function(msg){
					try {
						var t = null;
						if ( msg.data && msg.data.length && typeof msg.data != 'string' ) {
							$.each(msg.data, function(i,m) {
								if ( m.t ) t = $(m.t);
								if ( m.e ) m.c = eval('(' + m.e + ')');
								if ( t && m.a ) t = t[m.a](m.c);
							});
						} else if ( msg.data && ( msg.data.e || msg.data.c || msg.data.a ) ) {
							var m = msg.data;
							if ( m.t ) t = $(m.t);
							if ( m.e ) m.c = eval('(' + m.e + ')');
							if ( t && m.a ) t = t[m.a](m.c);
						} else if ( msg.e || msg.c || msg.a ) {
							var m = msg;
							if ( m.t ) t = $(m.t);
							if ( m.e ) m.c = eval('(' + m.e + ')');
							if ( t && m.a ) t = t[m.a](m.c);
						} else {
							self.onerror({name:"Parse Error", message:msg});
						}
					} catch(err) { 
						self.onerror(err);
					}
				},
				send: function(data) {
					if ( self._ws.readyState != WebSocket.OPEN ) {
						return self.onerror({name:"Invalid state" + self._ws.readyState,message:"Not connected."});
					} else {
						return self._ws.send(self.encode(data));
					};
				},
				connect: function() {
					if ( self._reconnectPending ) {
						clearTimeout(self._reconnectPending);
						self._reconnectPending = null;
					}
					if ( self._retryCount++ > self.maxRetries ) {
						return self.onerror({name:"WebSocket Error", message: "Exceeded max retry count of " + self.maxRetries + ".  Reconnect aborted."});
					}
					if ( self._ws ) {
						self.destroy();
					}
					self._ws = new WebSocket(self.url,self.protocols);
					if ( self.encoding == 'msgpack' ) {
						self._ws.binaryType = 'arraybuffer';
					}
					if (!self._ws) {
						self.onerror({name:"WebSocket Error",message:"Could not create a native WebSocket connection\nPlease install a modern browser like Google Chrome."});
					} else {
						$(self._ws).bind('open', function(e) {
							self._retryCount = 0;
							if ( self._reconnectPending ) {
								clearTimeout(self._reconnectPending);
								self._reconnectPending = null;
							}
							self.readyState = WebSocket.OPEN;
							return self.onopen(e);
						})
						.bind('close', function (e) {
							if ( ! self._reconnectPending ) self._reconnectPending = setTimeout(function() { self.connect() },self.retryDelay );
							return self.onclose(e);
						})
						.bind('error', function(e) {
							return self.onerror(e);
						})
						.bind('message', function(e) {
							console.log(e);
							var data = self.decode(e.originalEvent.data);
							return self.onmessage(data);
						});
					}
				},
				init: function() {
					$(window).bind('beforeunload',function(){ self.destroy() });
					if ( ! self.encode && self.encoding == 'msgpack' && typeof msgpack == 'object' ) {
						self.encode = function(data) {
							return msgpack.pack(data,true);
						};
						self.decode = function(data) {
							return msgpack.unpack(data);
						};
					} else if ( ! self.encode && self.encoding == 'json' && typeof $.toJSON == 'function' ) { 
						self.encode = $.toJSON;
						self.decode = $.evalJSON;
					} else {
						return self.onerror({name:"JWS Error",message:"Unable to load encoding: " + self.encoding});
					}
					if ( self.autoConnect ) self.connect();
				},
				destroy: function() {
					if ( self._ws && self._ws.readyState === WebSocket.OPEN ) {
						self.send({eventName:'close'})
						self._ws.close();
					}
					self._ws = null;
				}
			},opt);
			this.init();
			return this;
		}
});
})(jQuery);
