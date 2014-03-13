AnyEvent--Web
=============

Fast, experimental AnyEvent based WebSocket server with HTTP and routing support.
This is still very much in flux, and has no real documentation.


Good things:

It's fast.  In HTTP mode, it can serve 20k requests/sec with full headers on a single thread.
It is designed to expand easily to more than one thread, when I get around to it.

Low memory footprint.  Built in caching.

Designed to be scalable out of the box, using Redis for session and PubSub support.

Ranged support for incremental file transfers.

Extensible routing based on any HTTP header element.

No port switching to enter WebSocket mode.  Everything runs on 80/443.



Bad things:

This project started as I WANTED to re-invent the wheel as a way to better understand everything involved.  As such, I 
re-invent the wheel way more than I should.  The entire project could be replaced by Mojolicious.

I support a narrow subset of the HTTP spec.  Just what I have needed.

It uses a much more monolithic appoach than it should, but at the end of the day, that is what was most performant.
