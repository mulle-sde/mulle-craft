# mulle-craft, 🚬 Build projects using cmake, configure or some other meta-build tools


Use it to build
[mulle-bootstrap](//www.mulle-kybernetik.com/software/git/mulle-bootstrap)
and
[cmake](//gitlab.kitware.com/cmake/cmake)
based projects conveniently on multiple platforms (OSX, Linux, Windows)

Where **mulle-bootstrap** solves the dependency problems of your project.
**mulle-craft** combines it with cmake to build your complete project. It is
useful to quickly build and test a project. It simplifies interfacing your
project with package managers like [homebrew](//brew.sh) or continous
integration services like [Travis CI](//travis-ci.org/).


### What mulle-craft does in a nutshell

Essentially, `mulle-craft` is a shortcut for typing:


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
[examples](examples) folder for two simple mulle-craft projects.


## Commands

**mulle-craft** comes in several guises as:


Command       | Description                                   | Usage
--------------|-----------------------------------------------|---------------
mulle-craft   | build project and dependencies                | [mulle-craft](dox/mulle-craft.md)
mulle-clean   | run clean on project and dependencies         | [mulle-clean](dox/mulle-clean.md)
mulle-git     | run git operation on project and dependencies | [mulle-git](dox/mulle-git.md)
mulle-install | install libraries and binaries somewhere      | [mulle-install](dox/mulle-install.md)
mulle-tag     | (git) tag project and dependencies            | [mulle-tag](dox/mulle-tag.md)
mulle-test    | run tests (see below)                         | [mulle-test](dox/mulle-test.md)
mulle-update  | pull changes on project and dependencies      | [mulle-update](dox/mulle-update.md)


## Install mulle-craft

### Windows: Install "Git for Windows" bash

> Before going down this road, try the new
> [bash/WSL](https://msdn.microsoft.com/de-de/commandline/wsl/about).

On Windows you need to install some more prerequisites first.

* Install [Visual Studio 2015 Community Edition](//beta.visualstudio.com/downloads/)
or better (free). Make sure that you install Windows C++ support. Also add git support.
* [Git for Windows](//git-scm.com/download/win) is included in VS 2015, make sure it's there
* [Python 2 for Windows](//www.python.org/downloads/windows/). Make sure that python is installed in **PATH**, which is not the default.
* [CMake for Windows](//cmake.org/download/). CMake should also add itself to **PATH**.

Reboot, so that Windows picks up the **PATH** changes (Voodoo).

Now the tricky part is to get the "Git For Windows" **bash** shell running with
the proper VisualStudio environment.  Assuming you kept the default settings
during install the "Git for Windows" bash should be located at
`C:\Program Files\Git\git-bash.exe`. Open the
"Developer Command Prompt for VS 2015" from the **Start** menu and execute
the bash from there. A second window with the bash should open.

Check that you have the proper environment for VisualStudio compilation with
`env`.


### OSX: Install mulle-craft using homebrew

Install the [homebrew](//brew.sh/) package manager, then

```
brew install mulle-kybernetik/software/mulle-craft
```

### Linux: Install mulle-craft using apt-get

Run with sudo:

```
curl -sS "https://www.mulle-kybernetik.com/dists/admin-pub.asc" | apt-key add -
echo "deb [arch=all] http://www.mulle-kybernetik.com `lsb_release -c -s` main" \
> "/etc/apt/sources.list.d/mulle-kybernetik.com-main.list"
apt-get -y --allow-unauthenticated install mulle-craft
```

### Linux: Install mulle-craft using linuxbrew

Install the [linuxbrew](//linuxbrew.sh/) package manager, then

```
brew install mulle-kybernetik/software/mulle-craft
```

### All Platforms: Install mulle-craft using git

```
git clone --branch release https://www.mulle-kybernetik.com/repositories/mulle-bootstrap
( cd mulle-bootstrap ; ./install.sh )
git clone --branch release https://www.mulle-kybernetik.com/repositories/mulle-craft
( cd mulle-craft ; ./install.sh )
```


## Example Travis-CI integration with linux using mulle-craft

Travis CI integration simplifies to a uniform `.travis.yml` file that one
can use unchanged in all `mulle-craft` aware C projects. The main effort is
getting a recent `cmake` installed on "precise" :


```
language: c

dist: precise
sudo: required

addons:
  apt:
    sources:
      - george-edison55-precise-backports # cmake 3.2.3 / doxygen 1.8.3
    packages:
      - cmake
      - cmake-data

before_install:
   - sudo mkdir -p /home/linuxbrew
   - sudo chown "$USER" /home/linuxbrew
   - cd /home/linuxbrew
   - HOME=/home/linuxbrew
   - git clone https://github.com/Linuxbrew/brew.git ~/.linuxbrew
   - PATH="$HOME/.linuxbrew/bin:$PATH"
   - brew update
   - brew install mulle-kybernetik/software/mulle-craft


script:
   - mulle-craft
   - mulle-test
```

## Example Homebrew / Linuxbrew integreation using mulle-craft

Homebrew integration has to be customized by project. Instead of using
**mulle-craft** to resolve the dependencies, you want **brew** to install them
for you. Installing and testing is provided by mulle-craft. This works on OS X
and Linux!


```
class MyFormula < Formula
  homepage <url>
  desc <desc>
  url <url>
  version <version>
  sha256 <sha256>

  depends_on <dependencies>

  depends_on 'mulle-kybernetik/software/mulle-craft' => :build

  def install
     system "mulle-install", "--prefix", "#{prefix}", "--homebrew"
  end

  test do
     system "mulle-test"
  end
end
```
