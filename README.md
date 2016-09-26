# mulle-install

Install [mulle-bootstrap](//www.mulle-kybernetik.com/software/git/mulle-bootstrap)
based projects conveniently on multiple platforms (OSX, Linux, Windows)

> If your project has no dependencies but is `cmake` based, **mulle-install**
> can be useful too.

**mulle-bootstrap** solves the dependency problems of your project during
development. But **mulle-install** is a tool to facilitate installation of your
project with a package manager like [homebrew](//brew.sh). It can also be used
standalone to just build your project.

## Installing mulle-install

```
brew tap mulle-kybernetik/software
brew install mulle-install
```

or manually:

Install [mulle-bootstrap](//www.mulle-kybernetik.com/repositories/mulle-bootstrap)  first.
Then:

```
git clone -b release https:://www.mulle-kybernetik.com/repositories/mulle-install
cd mulle-install
./install.sh
```

## Usage

#### Common Options

Option      | Description                                   |
------------|-----------------------------------------------|
-d          | Build debug                                   |
-n          | Dry run, don't actually execute               |
-v          | Verbose                                       |
-vv         | Very verbose                                  |
-vvv        | Extremely verbose                             |
-t          | Trace shell script                            |


### URL mode

```
mulle-install https://github.com/my-name/my-repo.git
```

When you specify an URL, **mulle-install** will use it to clone a repository
from. It will then use **mulle-bootstrap** to acquire the necessary
dependencies and build the project. If the build was successful, the output
of the project **and** the built dependencies are installed.

#### Options in URL Mode

Option            |  Description                                  |
------------------|-----------------------------------------------|
-b &lt;branch&gt; | Tag/branch to fetch                           |
-s &lt;scm&gt;    | SCM to use (default: git).                    |
-p &lt;prefix&gt; | Installation prefix.                          |


### Local mode

```
mulle-install
```

If you do not specify an URL. **mulle-install** will assume that the current
directory is the project directory. If a `.bootstrap` folder is present it
will fetch all dependencies. Then it will build those dependencies using **cmake**.
Finally the product **and** the built dependencies are installed.


#### Options in Local Mode

Option            | Description                                   |
------------------|-----------------------------------------------|
-f                | Do not build dependencies via mulle-bootstrap. mulle-bootstrap will fetch only embedded repositories. This is useful if the dependencies are installed by brew or some other package manager. |
-m &lt;exe&gt;    | Specify the make program to use               |
-p &lt;prefix&gt; | Installation prefix                           |


## Typical usage with package manager "homebrew"

You want to create a "homebrew" formula. Your dependencies are also managed
my homebrew. So you don't build the dependencies again, just specify them
with homebrew to fetch:

```
class MyFormula < Formula
  ...
  depends_on 'MyOtherFormula'
  depends_on 'mulle-install' => :build

  def install
     system "mulle-install", "-f", "-p", "#{prefix}"
  end
  ...
end
```

## Typical usage with no package manager

**mulle-install** will do it all for you in URL mode:

```
mulle-install --prefix /opt --branch release https://github.com/my-name/my-repo.git
```

**mulle-install** in local mode:

```
mulle-install --prefix /opt
```




