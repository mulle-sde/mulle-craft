cmake_minimum_required (VERSION 3.0)

# use C, because otherwise a CXX compiler is required
project( mulle-craft NON)

#
# Primarily used for packaging on Linux
#
# Debian:
#
# ```
# mkdir package
# cd package
# cmake ..
# cpack -G DEB
# ```
#

execute_process( COMMAND ./mulle-craft version
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 OUTPUT_VARIABLE MULLE_CRAFT_VERSION
                 OUTPUT_STRIP_TRAILING_WHITESPACE)
message( STATUS "MULLE_CRAFT_VERSION is ${MULLE_CRAFT_VERSION} according to mulle-craft")


set( PROJECT_VERSION "${MULLE_CRAFT_VERSION}")


set( SCRIPTS
mulle-craft
)

set( LIBRARY_SCRIPTS
src/mulle-craft-clean.sh
src/mulle-craft-dependencies.sh
src/mulle-craft-execute.sh
)


INSTALL( FILES ${SCRIPTS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "bin")


INSTALL( FILES ${LIBRARY_SCRIPTS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "libexec/mulle-craft")




######
#
# must be after CPACK_PACKAGE_VERSION
include( CMakePackage.txt)
include( CPack)

