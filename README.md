# mulle-install

Install mulle-bootstrap based projects conveniently on multiple platforms
(OSX, Linux, Windows)

What it can do:

* git clone a project via URL
* fetch and build dependencies of this URL via mulle-bootstrap
* install products


## Options

Option      |
------------|------------------------------------------------------------
-b          | Do not build and install dependencies via mulle-bootstrap.
            | mulle-bootstrap will fetch only embedded repositories. This
            | is useful if the dependencies are installed by brew or some
            | other package manager globally.
-m <exe>    | Specify the make program to use
-c <url>    | Clone project from this URL
-r <root>   | Use a fake mulle-bootstrap root to build. This creates a folder
            | <root>. Initalizes it with `mulle-bootstrap init -n" and then
            | adds the <url> given with -c to the repositories list.
            | The dependency is then fetched and compiled.

