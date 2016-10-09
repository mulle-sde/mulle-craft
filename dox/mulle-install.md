### mulle-install


If mulle-build is like `make` then **mulle-install** is like `make install`.

```
mulle-install
```

**mulle-install** builds your project and it's dependencies
first just like **mulle-build**. If the build was successful, the output of
the project **and** the built dependencies are installed.
This is called "Local Mode".

But **mulle-install** can do an additional trick which is called "URL Mode".

```
mulle-install https://github.com/my-name/my-repo.git
```

When you specify an URL, **mulle-install** will use it to clone a repository
from. It will then use **mulle-bootstrap** to acquire the necessary
dependencies and build the project.

If the build was successful, the output of the project **and** the built
dependencies are installed.



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



#### Options in Local Mode

Option            | Description                                   |
------------------|-----------------------------------------------|
-nb               | Do not build dependencies via mulle-bootstrap. mulle-bootstrap will fetch only embedded repositories. This is useful if the dependencies are installed by brew or some other package manager.  |
-m &lt;exe&gt;    | Specify the make program to use               |
-p &lt;prefix&gt; | Installation prefix                           |



#### Options in URL Mode

Option            |  Description                                  |
------------------|-----------------------------------------------|
-b &lt;branch&gt; | Tag/branch to fetch                           |
-nr               | Do not remove temporary files (keep download) |
-p &lt;prefix&gt; | Installation prefix.                          |
-s &lt;scm&gt;    | SCM to use (default: git).                    |




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




