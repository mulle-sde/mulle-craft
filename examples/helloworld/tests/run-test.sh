#!/bin/sh

result="`../build/helloworld`"

if [ "${result}" != "Hello World!" ]
then
    echo "Test failed" >&2
    exit 1
fi
