# mulle-build

Build [mulle-bootstrap](//www.mulle-kybernetik.com/software/git/mulle-bootstrap)
and [cmake](//gitlab.kitware.com/cmake/cmake) based projects conveniently on
multiple platforms (OSX, Linux, Windows)

**mulle-bootstrap** solves the dependency problems of your project during
development. **mulle-build** facilitates building your project
with cmake and your dependencies with **mulle-bootstrap**.

With it's companion **mulle-build** it can be used to build a
project with a package manager like [homebrew](//brew.sh). It can also be used
standalone to just build your project.

## Installing mulle-build

```
brew tap mulle-kybernetik/software
brew install mulle-build
```

or manually:

Install [mulle-bootstrap](//www.mulle-kybernetik.com/repositories/mulle-bootstrap)  first.
Then:

```
git clone -b release https:://www.mulle-kybernetik.com/repositories/mulle-build
cd mulle-build
./install.sh
```

## mulle-build and mulle-install usage

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
-f                | Do not build dependencies via mulle-bootstrap. mulle-bootstrap will fetch only embedded repositories. This is useful if the dependencies are installed by brew or some other package manager. |
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
     system "mulle-install", "-f", "-p", "#{prefix}"
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




