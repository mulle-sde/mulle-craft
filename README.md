# mulle-craft, 🚬 Build projects with and without mulle source-trees

![Last version](https://img.shields.io/github/tag/mulle-nat/mulle-craft.svg)

... for Linux, OS X, FreeBSD, Windows

**mulle-craft** builds your project and it's dependencies. The dependencies are specified using [mulle-sourcetree](https://github.com/mulle-nat/mulle-sourcetree). 

> **mulle-craft** is the successor to [mulle-build](https://github.com/mulle-nat/mulle-sourcetree).


Executable    | Description
--------------|--------------------------------
`mulle-craft` | Build projects and their dependencies


## Install

OS    | Command
------|------------------------------------
macos | `brew install mulle-kybernetik/software/mulle-craft`
other | ./install.sh  (Requires: [mulle-sourcetree](https://github.com/mulle-nat/mulle-sourcetree),[mulle-make](https://github.com/mulle-nat/mulle-make),[mulle-dispense](https://github.com/mulle-nat/mulle-dispense))


## What mulle-craft does

Essentially, `mulle-craft` is a shortcut for typing:

```
for i in `mulle-sourcetree buildorder`
do
   mulle-make install --prefix "${tmpdir}" "$i"
   mulle-dispense "${tmpdir}" "${DEPENDENCIES_DIR}
done

mulle-make build "${PWD}"
```

So it's conceptually fairly simple, if you know how [mulle-sourcetree](https://github.com/mulle-nat/mulle-sourcetree) and [mulle-make](https://github.com/mulle-nat/mulle-make) and [mulle-dispense](https://github.com/mulle-nat/mulle-dispense) work. 

But then there are also variations and options :) 


## GitHub and Mulle kybernetiK

The development is done on [Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-craft/master). Releases and bug-tracking are on [GitHub](https://github.com/{{PUBLISHER}}/mulle-craft).


