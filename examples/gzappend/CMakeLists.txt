cmake_minimum_required(VERSION 3.0.0)

project (gzappend)

set( CMAKE_LIBRARY_PATH
"${CMAKE_LIBRARY_PATH}"
"dependencies/lib"
"addictions/lib"
)

include_directories( BEFORE SYSTEM
"dependencies/include"
"addictions/include"
)

find_library( ZLIB NAMES z)

add_executable( gzappend
src/gzappend.c
)

target_link_libraries( gzappend ${ZLIB})
install( TARGETS gzappend DESTINATION bin)
