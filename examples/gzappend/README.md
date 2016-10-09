# gzappend

This is a verbatim copy of example code from [zlib](//github.com/madler/zlib).
It demonstrates building zlib as a dependency and then compiling the example.
Checkout the `.bootstrap` folder, to see how the dependency is specified.


To see mulle-build in action

```
mulle-build
./build/gzappend
```

To see mulle-install in action

```
mulle-clean dist
mulle-install -p /tmp
ls -l /tmp/include /tmp/bin /tmp/lib
```

