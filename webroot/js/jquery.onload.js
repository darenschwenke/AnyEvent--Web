
var canvas;
var pen;
var moving = false;
drawLine = function(coordinates) {
	var start = coordinates.pop;
	var	pen = canvas[0].getContext( "2d" );
	pen.beginPath();
	pen.moveTo(start.x,start.y);
	for (var i = 0; i < coordinates.length; i++) {
		var pos = coordinates[i];
		pen.lineTo(pos.x,pos.y);
		pen.stroke();
	}
}
//(function($){
//})(jQuery);

$(document).ready(function() {
	canvas = $( "canvas" );
	var getPos = function(event){
		console.log(event);
		//if ( window.event.targetTouches && window.event.targetTouches.length ) event = window.event.targetTouches[0];
		var position = canvas.offset();
		return({x:parseInt(event.pageX - position.left),y:parseInt(event.pageY - position.top)});
	};
	var coordinates = new Array();
	canvas.on("touchstart mousedown", function(event){
		var pos = getPos(event);
		pen = canvas[0].getContext( "2d" );
		pen.beginPath();
		pen.moveTo(pos.x,pos.y);
		coordinates.push(pos);
		moving = true;
		return false;
	}).on("touchmove mousemove", function(event){
		if ( ! moving ) return false;
		var pos = getPos(event);
		pen.lineTo(pos.x,pos.y);
		coordinates.push(pos);
		pen.stroke();
		return false;
	}).on("touchend mouseup", function(event){
		var pos = getPos(event);
		pen.lineTo(pos.x,pos.y);
		coordinates.push(pos);
		pen.stroke();
		es.send({eventName:'drawLine',coordinates:coordinates});
		coordinates = new Array();
		moving = false;
		return false;
	});
	es = $.esEngine({url:'ws://__WS_HOST__/jqws'});
});
