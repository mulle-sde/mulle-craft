## mulle-test usage

`usage: mulle-test [flags] [test options]`


It is assumed that you have a folder `tests` in your project directory.
Inside this directory **mulle-test** expects to find two scripts:

* `build-test.sh` to build the test libraries or executables. It is optional.
* `run-test.sh` to actually build and run the individual tests.

```console
./tests
./tests/buid-test.sh
./tests/run-test.sh
```

[mulle-tests](//www.mulle-kybernetik.com/repositories/mulle-tests) has
some ready made shell script code to write cross-platform tests.
Also [mulle-sde](//www.mulle-kybernetik.com/repositories/mulle-sde) will
provide some support to set this up for your project automatically.


#### Flags

Flag        | Description                                   |
------------|-----------------------------------------------|
-n          | Dry run, don't actually execute               |
-v          | Verbose                                       |
-vv         | Very verbose                                  |
-vvv        | Extremely verbose                             |
-t          | Trace shell script                            |
