# mulle-craft, 🚬 Build projects with and without mulle sourcetrees

![Last version](https://img.shields.io/github/tag/mulle-nat/mulle-craft.svg)

... for Linux, OS X, FreeBSD, Windows

![Overview](mulle-craft-overview.png)

**mulle-craft** builds your project and it's dependencies. The dependencies are specified using [mulle-sourcetree](https://github.com/mulle-sde/mulle-sourcetree).


Executable    | Description
--------------|--------------------------------
`mulle-craft` | Build projects and their dependencies


> **mulle-craft** is the successor to [mulle-build](https://github.com/mulle-nat/mulle-build).


## Install

OS    | Command
------|------------------------------------
macos | `brew install mulle-kybernetik/software/mulle-craft`
other | ./install.sh  (Requires: [mulle-sourcetree](https://github.com/mulle-sde/mulle-sourcetree),[mulle-make](https://github.com/mulle-sde/mulle-make),[mulle-dispense](https://github.com/mulle-sde/mulle-dispense))


## What mulle-craft does

Essentially, `mulle-craft` is a shortcut for typing:

```
# Build the dependencies
for i in `mulle-sourcetree buildorder`
do
   mulle-make install --prefix "${tmpdir}" "$i"
   mulle-dispense "${tmpdir}" "${DEPENDENCY_DIR}
done

# Build the project
mulle-make build "${PWD}"
```

So it's conceptually fairly simple, if you know how [mulle-sourcetree](https://github.com/mulle-sde/mulle-sourcetree) and [mulle-make](https://github.com/mulle-sde/mulle-make) and [mulle-dispense](https://github.com/mulle-sde/mulle-dispense) work.

But then there are also variations and options :)

## The *info folder*

**mulle-make** accepts a so called *info-folder*, which contains compile
flags and environment variables to build a project.

These can be platform specific, but don't have to be. It is one of
**mulle-craft** tasks to pick the right *info-folder* and feed it to
**mulle-make**.


## How mulle-craft searches for the *info-folder*

First the `dependencies/share/mulle-craft` folder will be searched
for any matches. A match is made if the name of the to-be-built
project is the same as the *info-folder* name (without extension).

An *info-folder* may have an extension, which can be one of the simplified
**mulle-craft uname** outputs, which are platform specificy.
A non matching "uname" extension is ignored. An *info-folder* with a matching
extension is preferred over a matching name with no extension.

Then the `.mulle-craft` folder of the current (mulle-sde) project is
searched.

Finally, if this is a dependency being buit and nothing has matched yet,
the projects own `.mulle-craft` folder contents will be considered.

Assume that you are on **darwin** in the following picture, the `.linux`
folder will be ignored:

![Searching](dox/searchpath.png)

## GitHub and Mulle kybernetiK

The development is done on [Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-craft/master). Releases and bug-tracking are on [GitHub](https://github.com/mulle-sde/mulle-craft).


