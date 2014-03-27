(function(window, undefined) {
"use strict";

var Floodlight = function() {
    var self = this
    self.init = function() {

    }
    self.track = function(type, cat) {
        //From floodlight example
        var isUnique = 0;
        var axel = Math.random()+"";
        var a = axel * 10000000000000000;
        var flDiv=document.body.appendChild(document.createElement("div"));
        var cachebust = (isUnique)?';ord=1;num=':';ord=';
        flDiv.setAttribute("id","DCLK_FLDiv1");
        flDiv.style.position="absolute";
        flDiv.style.top="0";
        flDiv.style.left="0";
        flDiv.style.width="1px";
        flDiv.style.height="1px";
        flDiv.style.display="none";
        flDiv.innerHTML='<iframe id="DCLK_FLIframe1" src="https://2542116.fls.doubleclick.net/activityi;src=2542116;type=' + type + ';cat=' + cat + cachebust + a + '?" width="1" height="1" frameborder="0"><\/iframe>';
        console.log('Tracking: '+flDiv.innerHTML)
    }
    self.init()
}

window._fl = new Floodlight()

}(window));
