0.9.1
=====

* fix --homebrew flag for linux

0.9.0
=====

* use eval exekutor for cmake/make to protect parameters
* add --homebrew switch to fix mulle-clang builds inside homebrew


0.8.2
=====

* protect homebrew shims from PATH shenanigans
* improve fail output


0.8.1
=====

* pass all flags -D*|-W* to cmake

0.8.0
=====

* mulle-build assumes mulle-bootstrap is installed besides it, if it is, that
becomes its preferential path for it
* allow to specify cmake commandline flags with -DCMAKE (will not get passed
to mulle_bootstrap)
* add --dump-environment as a debug option

0.7.0
=====

* adapt to mulle-bootstrap 2.4.0

0.6.1
=====

* pass --debug to ./build-test.sh

0.6
=====

* added mulle-status, because I use it so often
* adapt to changes in mulle-build


0.5.3
=====

* mulle-update is more verbose and better at detecting remotes, who are not
named "origin"

0.5.2
=====

* be more verbose when tagging

0.5.1
=====

* fix use of CMAKE_INSTALL_PREFIX
* remove some unnecesary refresh calls to make things go faster

0.5
===

Mostly changes how flags are interpreted and passed to mulle-bootstrap.

* change -nb flag to -nbd

0.4
===

* Much improved documentation
* Fix mulle-clean a bit

0.3
===

* base code on mulle-bootstrap library functions for exekutor and logging
* add multiple options
* check for mulle-bootstrap version
* rename project from mulle-install to mulle-build
* do local command first, mulle-bootstrap later (f.e. for tagging). That way
more numerous local failures don't dirty dependencies.
* this version needs to be pushed out now, because I need it in travis.yml

0.2
===

* allow to specify a tag and a scm for URL install
