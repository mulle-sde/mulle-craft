# mulle-build

... simplifies the use of mulle-bootstrap and cmake.

Use it to build [mulle-bootstrap](//www.mulle-kybernetik.com/software/git/mulle-bootstrap) and [cmake](//gitlab.kitware.com/cmake/cmake) based
projects conveniently on multiple platforms (OSX, Linux, Windows)

Where **mulle-bootstrap** solves the dependency problems of your project.
**mulle-build** combines it with cmake to build your complete project.


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

So it's conceptually fairly simple. But then there are options :)
**mulle-build** comes in several guises as:


Command       | Description
--------------|-------------------
mulle-clean   | run clean on project and dependencies
mulle-git     | run git operation on project and dependencies (e.g. `mulle-git status`)
mulle-install | install libraries and binaries somewhere
mulle-tag     | (git) tag project and dependencies
mulle-test    | run tests (see below)
mulle-update  | pull changes on project and dependencies



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


## mulle-build usage

You should configure your project with a `CMakeLists.txt` file. Check out the [cmake Tutorial](https://cmake.org/cmake-tutorial/) if you are unfamiliar with cmake.
> Also [mulle-sde](//www.mulle-kybernetik.com/repositories/mulle-sde) can be
> helpful there. But as of 11/16 it's still very much experimental.


Since it's generally not useful to specify the compiler inside the `CMakeLists.txt` file, you can use

```
echo "gcc" > .CC
echo "clang" > .CXX
```

to specify the C and CXX compiler. For Objective-C it is platform dependent, which compiler is used to compile `.m`files.

> Interestingly these settings are also picked up as defaults by
> **mulle-bootstrap** if your project becomes a dependency to another
> project.


## mulle-test usage

It is assumed that you have a folder `tests` in your project directory.
Inside this directory it is expected to find two scripts:

* `build-test.sh` to build the test libraries or executables
* `run-test.sh` to actually build and run the individual tests.


[mulle-tests](//www.mulle-kybernetik.com/repositories/mulle-tests) has
some ready made shell script code to write cross-platform tests.
Also [mulle-sde](//www.mulle-kybernetik.com/repositories/mulle-sde) will
provide some support to set this up for your project automatically.



#### Common Options

Option      | Description                                   |
------------|-----------------------------------------------|
-d          | Build debug                                   |
-n          | Dry run, don't actually execute               |
-ni         | Do not install                                |
-v          | Verbose                                       |
-vv         | Very verbose                                  |
-vvv        | Extremely verbose                             |
-t          | Trace shell script                            |


### mulle-build in URL mode

```
mulle-build https://github.com/my-name/my-repo.git
```

When you specify an URL, **mulle-build** will use it to clone a repository
from. It will then use **mulle-bootstrap** to acquire the necessary
dependencies and build the project. Afterwards everything is thrown away!


### mulle-install in URL mode

```
mulle-install https://github.com/my-name/my-repo.git
```

Works like mulle-build in URL mode. If the build was successful, the output
of the project **and** the built dependencies are installed.


#### Options in URL Mode

Option            |  Description                                  |
------------------|-----------------------------------------------|
-b &lt;branch&gt; | Tag/branch to fetch                           |
-nr               | Do not remove temporary files (keep download) |
-p &lt;prefix&gt; | Installation prefix.                          |
-s &lt;scm&gt;    | SCM to use (default: git).                    |


### mulle-build in local mode

If you do not specify an URL. **mulle-build** will assume that the current
directory is the project directory. If a `.bootstrap` folder is present it
will fetch all dependencies. Then it will build your project using **cmake**.
Where mulle-bootstrap is pessimistic, mulle-build is optimistic. If a
dependencies folder is present, it assumes that mulle-bootstrap need not run.
If it detects the presence of cmake generated files, it will not run **cmake**
again, but just make.


### mulle-install in local mode

```
mulle-install
```

Works like mulle-build in local mode. If the build was successful, the output
of the project **and** the built dependencies are installed.


#### Options in Local Mode

Option            | Description                                   |
------------------|-----------------------------------------------|
-nb               | Do not build dependencies via mulle-bootstrap. mulle-bootstrap will fetch only embedded repositories. This is useful if the dependencies are installed by brew or some other package manager.  |
-m &lt;exe&gt;    | Specify the make program to use               |
-p &lt;prefix&gt; | Installation prefix                           |


## mulle-install with package manager "homebrew"

You want to create a "homebrew" formula. Your dependencies are also managed
my homebrew. So you don't build the dependencies (-f), but you do need the
embedded repositories:

```
class MyFormula < Formula
  ...
  depends_on 'MyOtherFormula'
  depends_on 'mulle-build' => :build

  def install
     system "mulle-install", "-nb", "-p", "#{prefix}"
  end
  ...
end
```

## mulle-install with no package manager

**mulle-install** will do it all for you in URL mode:

```
mulle-install --prefix /opt --branch release https://github.com/my-name/my-repo.git
```

**mulle-install** in local mode:

```
mulle-install --prefix /opt
```




