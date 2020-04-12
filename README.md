# mulle-craft

🚬 Build projects with and without mulle sourcetrees

![Last version](https://img.shields.io/github/tag/mulle-sde/mulle-craft.svg)

... for Linux, OS X, FreeBSD, Windows

![Overview](dox/mulle-sde-overview.png)

**mulle-craft** builds two things:

* your *project* using [mulle-make](https://github.com/mulle-sde/mulle-make)
* the dependencies of your project as specified by a *craftorder* file. This
file can be generated by [mulle-sourcetree](https://github.com/mulle-sde/mulle-sourcetree).

*mulle-craft* is unaware of the build tool to use (e.g. *cmake* or *xcodebuild*).
That is determined by *mulle-make*, which gets called from *mulle-craft*.


Executable    | Description
--------------|--------------------------------
`mulle-craft` | Build projects and their dependencies


> **mulle-craft** is the successor to
> [mulle-build](https://github.com/mulle-nat/mulle-build).



## What mulle-craft does

Essentially, `mulle-craft` is a shortcut for typing:

```
# Build the dependencies
for project in `mulle-sourcetree craftorder`
do
   for sdk in ${SDKS}
   do
      for platform in ${PLATFORMS}
      do
         for configuration in ${CONFIGURATIONS}
         do
            mulle-make install --configuration "${configuration}" \
                               --sdk "${sdk}" \
                               --platform "${platform}" \
                               --prefix "${tmpdir}" \
                               "${project}"
            mulle-dispense "${tmpdir}" "${DEPENDENCY_DIR}/${sdk}-${platform}/${configuration}
         done
      done
   done
done

# Build the project
mulle-make craft "${PWD}"
```


So it's conceptually fairly simple, if you know how
[mulle-sourcetree](https://github.com/mulle-sde/mulle-sourcetree) and
[mulle-make](https://github.com/mulle-sde/mulle-make) and
[mulle-dispense](https://github.com/mulle-sde/mulle-dispense) work.

But then there are also variations and options :)


### The *info folder*

**mulle-make** accepts a so called *info-folder*, which contains compile
flags and environment variables to craft a project.

These can be platform specific, but don't have to be. It is one of
**mulle-craft** tasks to pick the right *info-folder* and feed it to
**mulle-make**.


#### How mulle-craft searches for the *info-folder*

First the `dependency/share/mulle-craft` folder will be searched
for matching folders. A match is made if the name of the to-be-built
project is the same as the *info-folder* name (without extension).

An *info-folder* may have an extension, which can be one of the simplified
`mulle-craft uname` outputs, which are platform specific.
An *info-folder* with a matching extension is preferred over a matching name
with no extension.

If mulle-craft finds no info-folder there then a project specific
`.mulle/etc/craft` or `.mulle/share/craft` folder is searched if present.

![Searching](dox/searchpath.png)


### Dispense styles

*mulle-craft* builds dependencies in various configuration such as
unoptimized (Debug) or optimized (Release). It can also craft for multiple
SDKs and platforms. If only a single depedency folder destination would be
used the output would clobber each other. That's where the *dispense style*
comes into play. The easiest to understand is the *strict* style.

![Strict](dox/dispense-strict.png)

> In this picture for simplicity it is assumed that there is only one
> platform. Otherwise the "sdk" folders would be multiplied by the number
> of platforms to craft for (with the platform name appended)

The `auto` style is the default and somewhat more convenient in actual usage:

![Auto](dox/dispense-auto.png)

Here the contents of the "Release" folders are moved upwards and the "Release"
folder itself is deleted.



## Install

See [mulle-sde-developer](//github.com/mulle-sde/mulle-sde-developer) how
to install mulle-sde.



## GitHub and Mulle kybernetiK

The development is done on
[Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-craft/master).
Releases and bug-tracking are on
[GitHub](https://github.com/mulle-sde/mulle-craft).


