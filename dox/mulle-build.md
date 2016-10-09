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




#### Options

Option            | Description                                   |
------------------|-----------------------------------------------|
-d                | Build debug                                   |
-n                | Dry run, don't actually execute               |
-ni               | Do not install                                |
-v                | Verbose                                       |
-vv               | Very verbose                                  |
-vvv              | Extremely verbose                             |
-t                | Trace shell script                            |
-nb               | Do not build dependencies via mulle-bootstrap. mulle-bootstrap will fetch only embedded repositories. This is useful if the dependencies are installed by brew or some other package manager.  |
-m &lt;exe&gt;    | Specify the make program to use               |
-p &lt;prefix&gt; | Installation prefix                           |


**mulle-build** assumes that the current directory is the project directory.
If a `.bootstrap` folder is present it will fetch all dependencies using
**mulle-bootstrap**. Then it will build your project using **cmake**.
Where mulle-bootstrap is pessimistic, mulle-build tries to be optimistic and
reduce duplicate effort. If a dependencies folder is present, it assumes that mulle-bootstrap need not run. If it detects the presence of cmake generated
files, it will not run **cmake** again, but just make.
