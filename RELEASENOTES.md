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
