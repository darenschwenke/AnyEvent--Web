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
var wse;
var dialog;
var tabs;
var editors = [];
(function($){
	$.extend({
		wse: function (opt) {
			var self;
			self = $.extend(this,{
				encoding: 'json',
				url: '',
				protocols: [],
				autoConnect: true,
				room_id: '',
				username: '',
				maxRetries: 10,
				readyState: WebSocket.CONNECTING,
				retryDelay: 1000,
				_reconnectPending: null,
				_retryCount: 0,
				_ws: null,
				encode: null,
				decode: null,
				onopen: function(e){self.send({eventName:'login', username: self.username, room_id: self.room_id})},
				onclose: function(e){console.log(e);},
				onerror: function(e){dialog.html(e.message).dialog("option",{title:e.name,show: { duration: 300 }, hide: { delay: 5000, effect: "fade", duration: 800 }}) },
				onmessage: function(msg){
					try {
						if ( msg.eventName == 'jQuery' ) {
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
								self.onerror({name:"jQuery parse error", message:msg});
							}
						} else if ( msg.eventName == 'setFilename' ) {
							getEditor(msg.id).setFilename(msg);
						} else if ( msg.eventName == 'setContext' ) {
							getEditor(msg.id).setContext(msg);
						} else if ( msg.eventName == 'applyDeltas' ) {
							getEditor(msg.id).applyDeltas(msg);
						} else if ( msg.eventName == 'newEditor' ) {
							newEditor(msg);
						} else if ( msg.eventName == 'getState' ) {
							getState(msg.id);
						} else {
							console.log(msg);
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
						return self.onerror({name:"Connection Error", message: "Exceeded max retry count of " + self.maxRetries + ".  Reconnect aborted."});
					}
					if ( self._ws ) {
						self.destroy();
					}
					self._ws = new WebSocket(self.url,self.protocols);
					if ( self.encoding == 'msgpack' ) {
						self._ws.binaryType = 'arraybuffer';
					}
					if (!self._ws) {
						self.onerror({name:"Connection Error",message:"Could not create a native WebSocket connection\nPlease install a modern browser like Google Chrome."});
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

function Editor (msg) {
	var self = this;
	this.keybindings = {    
		ace: null, 
		vim: ace.require("ace/keyboard/vim").handler,
		emacs: "ace/keyboard/emacs"
	};
	this.applying = false;
	this.context = $("#default-context").val();
	this.keybinding = $("#keybinding").val();
	for ( var p in msg ) {
		if ( p != 'value' ) {
			this[p] = msg[p];
		}
	}
	if ( ! this.filename ) this.filename = 'untitled-' + this.id + '.txt';
	this.name = "editor-" + this.id;
	this.deltas = [];
	$("div#tabs").append('<div id="' + this.name + '" class="editor-container"><div class="editor-options"><label for="' + this.name + '-context">Context</label><select id="' + this.name + '-context" size="1"> <option value="abap">ABAP</option><option value="actionscript">ActionScript</option><option value="ada">ADA</option><option value="apache_conf">Apache Conf</option><option value="asciidoc">AsciiDoc</option><option value="assembly_x86">Assembly x86</option><option value="autohotkey">AutoHotKey</option><option value="batchfile">BatchFile</option><option value="c9search">C9Search</option><option value="c_cpp">C/C++</option><option value="cirru">Cirru</option><option value="clojure">Clojure</option><option value="cobol">Cobol</option><option value="coffee">CoffeeScript</option><option value="coldfusion">ColdFusion</option><option value="csharp">C#</option><option value="css">CSS</option><option value="curly">Curly</option><option value="d">D</option><option value="dart">Dart</option><option value="diff">Diff</option><option value="dot">Dot</option><option value="erlang">Erlang</option><option value="ejs">EJS</option><option value="forth">Forth</option><option value="ftl">FreeMarker</option><option value="gherkin">Gherkin</option><option value="glsl">Glsl</option><option value="golang">Go</option><option value="groovy">Groovy</option><option value="haml">HAML</option><option value="handlebars">Handlebars</option><option value="haskell">Haskell</option><option value="haxe">haXe</option><option value="html">HTML</option><option value="html_ruby">HTML (Ruby)</option><option value="ini">INI</option><option value="jack">Jack</option><option value="jade">Jade</option><option value="java">Java</option><option value="javascript">JavaScript</option><option value="json">JSON</option><option value="jsoniq">JSONiq</option><option value="jsp">JSP</option><option value="jsx">JSX</option><option value="julia">Julia</option><option value="latex">LaTeX</option><option value="less">LESS</option><option value="liquid">Liquid</option><option value="lisp">Lisp</option><option value="livescript">LiveScript</option><option value="logiql">LogiQL</option><option value="lsl">LSL</option><option value="lua">Lua</option><option value="luapage">LuaPage</option><option value="lucene">Lucene</option><option value="makefile">Makefile</option><option value="matlab">MATLAB</option><option value="markdown">Markdown</option><option value="mel">MEL</option><option value="mysql">MySQL</option><option value="mushcode">MUSHCode</option><option value="nix">Nix</option><option value="objectivec">Objective-C</option><option value="ocaml">OCaml</option><option value="pascal">Pascal</option><option value="perl" selected="selected">Perl</option><option value="pgsql">pgSQL</option><option value="php">PHP</option><option value="powershell">Powershell</option><option value="prolog">Prolog</option><option value="properties">Properties</option><option value="protobuf">Protobuf</option><option value="python">Python</option><option value="r">R</option><option value="rdoc">RDoc</option><option value="rhtml">RHTML</option><option value="ruby">Ruby</option><option value="rust">Rust</option><option value="sass">SASS</option><option value="scad">SCAD</option><option value="scala">Scala</option><option value="smarty">Smarty</option><option value="scheme">Scheme</option><option value="scss">SCSS</option><option value="sh">SH</option><option value="sjs">SJS</option><option value="space">Space</option><option value="snippets">snippets</option><option value="soy_template">Soy Template</option><option value="sql">SQL</option><option value="stylus">Stylus</option><option value="svg">SVG</option><option value="tcl">Tcl</option><option value="tex">Tex</option><option value="text">Text</option><option value="textile">Textile</option><option value="toml">Toml</option><option value="twig">Twig</option><option value="typescript">Typescript</option><option value="vbscript">VBScript</option><option value="velocity">Velocity</option><option value="verilog">Verilog</option><option value="xml">XML</option><option value="xquery">XQuery</option><option value="yaml">YAML</option> </select> <label for="' + this.name + '-filename">Filename</label><input id="' + this.name + '-filename" type=text value="' + this.filename + '"> <button id="' + this.name + '-download">Download</button></div> <div id="' + this.name + '-ace" class="editor-ace"></div></div>');
	$("div#tabs ul").append('<li><a href="#' + this.name + '" id="' + this.name + '-tab">' + this.filename + '</a></li>');
	tabs.tabs("refresh");
	$("#" + this.name + "-tab").trigger("click");
	this.ace = ace.edit(this.name + '-ace');
	this.ace.setTheme("ace/theme/" + $("#theme").val());
	if ( msg.value ) this.ace.setValue(msg.value);
	this.ace.getSession().getDocument().on("change",function(e) { if ( ! self.applying ) self.deltas.push(e.data); } );
	this.ace.getSelection().on("changeCursor",function(e) { if ( ! self.applying ) return console.log(self.ace.getSelection().getCursor()); } );
	this.ace.getSelection().on("changeSelection",function(e) { if ( ! self.applying ) return console.log(self.ace.getSelection().getRange()); } );
	this.ace.on("changeStatus",function(e) { if ( ! self.applying ) return console.log("cursor", self.ace.renderer.content.style.cursor,"range",self.ace.getSelection().getRange()); } );
	this.setKeybinding = function(msg) {
		this.keybinding = msg.keybinding;
		this.ace.setKeyboardHandler(this.keybindings[this.keybinding]);
	}
	this.applyDeltas = function(msg) {
		if ( msg.remote ) this.applying = true;
		this.ace.getSession().getDocument().applyDeltas(msg.deltas);
		if ( msg.remote ) this.applying = false;
	}
	this.setFilename = function(msg) {
		this.filename = msg.filename;
		$("#editor-" + this.id + "-tab").html(this.filename); 
		if ( ! msg.remote) this.wse.send({eventName:"setFilename",remote: 1, id: this.id, filename: this.filename});
	}
	this.setContext = function(msg) {
		this.context = msg.context;
		this.ace.getSession().setMode("ace/mode/" + this.context);
		if ( ! msg.remote) this.wse.send({eventName:"setContext",remote: 1, id: this.id, context: this.context});
	}
	this.setTheme = function(msg) {
		this.theme = msg.theme;
		this.ace.setTheme("ace/theme/" + this.theme);
		if ( ! msg.remote) this.wse.send({eventName:"setTheme",remote: 1, id: this.id, theme: this.theme});
	}
	this.getState = function() {
		return {eventName: "newEditor", remote: 1, id: this.id, filename: this.filename, context: this.context, value: this.ace.getValue()};
	}
	$("#" + this.name + "-context").on("change", function () { 
		self.setContext({context: this.value}); }
	).val(this.context).change();
	$("#" + this.name + "-filename").on("change", function () { 
		self.setFilename({filename: this.value}); }
	).val(this.filename).change();
	$("#" + this.name + "-download").on("click", function() {
		var blob = new Blob([self.ace.getValue()], {type: "text/plain;charset=utf-8"});
		window.saveAs(blob,self.filename);
	});
	this.saveState = function() {
		self.wse.send({eventName:"saveState",id: this.id, filename: this.filename, context: this.context, value: this.ace.getValue()});
	}
	this.pushDeltas = setInterval(function() { if ( self.deltas.length > 0 ) self.wse.send({eventName:"applyDeltas",remote: 1, id: self.id, deltas:self.deltas.splice(0,self.deltas.length)}); },250);
	this.pushState = setInterval(function() { self.saveState(); },30000);
	setTimeout(function() { $("#keybinding").trigger("change"); },500);
};
function newEditor (msg) {
	if ( ! msg ) msg = { id: editors.length };
	if ( ! msg.wse ) msg.wse = wse;
	if ( editors[msg.id] === undefined ) {
		editors[msg.id] = new Editor(msg);
		wse.send(editors[msg.id].getState());
	}
}
function getEditor(id) {
	return editors[id];
}
function getState(id) {
	wse.send(getEditor(id).getState());
}

