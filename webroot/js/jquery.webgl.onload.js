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

var wse;
$(document).ready(function() {
	wse = $.wse({url:'ws://__WS_HOST__/webgl',encoding:'json'});
});
