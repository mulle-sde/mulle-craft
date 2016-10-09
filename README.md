# mulle-build

... simplifies the use of mulle-bootstrap and cmake.

> Caveat: It's very much a 0.x project yet.

Use it to build [mulle-bootstrap](//www.mulle-kybernetik.com/software/git/mulle-bootstrap) and [cmake](//gitlab.kitware.com/cmake/cmake) based
projects conveniently on multiple platforms (OSX, Linux, Windows)

Where **mulle-bootstrap** solves the dependency problems of your project.
**mulle-build** combines it with cmake to build your complete project. It is
useful to quickly build and test a project. It simplifies interfacing your
project with package managers like [homebrew](//brew.sh) or continous
integration services like [Travis CI](//travis-ci.org/).


### What mulle-build does in a nutshell


Essentially, `mulle-build` is a shortcut for typing:


```
# fetch and build dependencies
mulle-bootstrap
# standard cmake build
mkdir build
cd build
cmake ..
make
```

So it's conceptually fairly simple. But then there are options :) Check the
[examples](examples) folder for two simple mulle-build projects.


## Commands

**mulle-build** comes in several guises as:


Command       | Description                                   | Usage
--------------|-----------------------------------------------|---------------
mulle-build   | build project and dependencies                | [mulle-build](dox/mulle-build.md)
mulle-clean   | run clean on project and dependencies         | [mulle-clean](dox/mulle-clean.md)
mulle-git     | run git operation on project and dependencies | [mulle-git](dox/mulle-git.md)
mulle-install | install libraries and binaries somewhere      | [mulle-install](dox/mulle-install.md)
mulle-tag     | (git) tag project and dependencies            | [mulle-tag](dox/mulle-tag.md)
mulle-test    | run tests (see below)                         | [mulle-test](dox/mulle-test.md)
mulle-update  | pull changes on project and dependencies      | [mulle-update](dox/mulle-update.md)


## Installing mulle-build

On OS X and Linux you can install using [homebrew](//brew.sh) respectively [linuxbrew](//linuxbrew.sh)

```
brew tap mulle-kybernetik/software
brew install mulle-build
```

On other platforms you need to do this manually:

Install [mulle-bootstrap](//www.mulle-kybernetik.com/repositories/mulle-bootstrap)
first.

```
git clone -b release https://www.mulle-kybernetik.com/repositories/mulle-bootstrap
( cd mulle-bootstrap ;  ./install.sh )
```

Then:

```
git clone -b release https://www.mulle-kybernetik.com/repositories/mulle-build
( cd mulle-build ;  ./install.sh )
```
