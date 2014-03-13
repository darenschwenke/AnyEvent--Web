window.URL = window.URL || window.webkitURL;
var video = document.querySelector('video');
var stream;
var audio = document.querySelector('audio');
function getUserMedia(dictionary, callback) {
    try {
        navigator.getUserMedia = 
        	navigator.getUserMedia ||
        	navigator.webkitGetUserMedia ||
        	navigator.mozGetUserMedia;
        navigator.getUserMedia(dictionary, callback, error);
    } catch (e) {
        console.log('Error:',e);
    }
}
getUserMedia({
	audio: true, 
	video: {
    		mandatory: {
      			maxWidth: 640,
      			maxHeight: 360,
      			frameRate: 10.0,
      			facingmode: 'user',
		}
  	}, 
	function(stream) {
  		video.src = window.URL.createObjectURL(stream);
  	}, 
	function(e) { 
		console.log('Failed:',e); 
	}
);
var context = new webkitAudioContext();
var mediaStreamSource = context.createMediaStreamSource(s);
	setTimeout( function(){ window.scrollTo( 0, 0 ); }, 50 );
