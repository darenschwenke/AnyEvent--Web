AnyEvent--Web
=============

Fast, experimental AnyEvent based WebSocket server with HTTP and routing support.
This was simply supposed to showcase the way I've implemented server side jQuery chaining in perl, but then it started performing really well..

Good things:

It's fast.  In HTTP mode, it can serve 20k requests/sec with full headers on a single thread.  If that scales, it could be the fastest Perl based webserver.

Low memory footprint.  

Built in caching (which I broke just now).

Designed to be scalable.  Uses Redis for PubSub, state, and events.

HTTP Ranged support for incremental file transfers and fully event based filesystem IO.

Extensible routing based on any HTTP header element with named parameter support.

No additional port required to upgrade to a WebSocket as same server handles both.


Bad things:

Hesitant to take this very far, as the entire project could be replaced by Mojolicious, PSGI, POE, etc..

I support a narrow subset of the HTTP spec.  Just what I have needed.

I re-invent the wheel a lot.

It uses a much more monolithic appoach than I wanted to.  I (re)wrote it layered, but the function calls were expensive and monolithic was more performant.
