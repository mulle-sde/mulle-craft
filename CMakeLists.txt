cmake_minimum_required (VERSION 3.0)

project( mulle-build)

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

execute_process( COMMAND ./mulle-build version
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 OUTPUT_VARIABLE MULLE_BUILD_VERSION
                 OUTPUT_STRIP_TRAILING_WHITESPACE)
message( STATUS "MULLE_BUILD_VERSION is ${MULLE_BUILD_VERSION} according to mulle-build")

execute_process( COMMAND ./mulle-build minimum-bootstrap-version
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 OUTPUT_VARIABLE MULLE_BOOTSTRAP_REQ_VERSION
                 OUTPUT_STRIP_TRAILING_WHITESPACE)
message( STATUS "Required MULLE_BOOTSTRAP_VERSION is ${MULLE_BOOTSTRAP_REQ_VERSION} according to mulle-build")


set( PROJECT_VERSION "${MULLE_BUILD_VERSION}")


set( SCRIPTS
mulle-build
)

#
# analyze clean git install status tag test
#
if( CMAKE_HOST_UNIX)
   set( SYMLINKS
"${CMAKE_BINARY_DIR}/mulle-analyze"
"${CMAKE_BINARY_DIR}/mulle-clean"
"${CMAKE_BINARY_DIR}/mulle-git"
"${CMAKE_BINARY_DIR}/mulle-install"
"${CMAKE_BINARY_DIR}/mulle-status"
"${CMAKE_BINARY_DIR}/mulle-tag"
"${CMAKE_BINARY_DIR}/mulle-test"
)
  execute_process(COMMAND ln -s mulle-build "${CMAKE_BINARY_DIR}/mulle-analyze")
  execute_process(COMMAND ln -s mulle-build "${CMAKE_BINARY_DIR}/mulle-clean")
  execute_process(COMMAND ln -s mulle-build "${CMAKE_BINARY_DIR}/mulle-git")
  execute_process(COMMAND ln -s mulle-build "${CMAKE_BINARY_DIR}/mulle-install")
  execute_process(COMMAND ln -s mulle-build "${CMAKE_BINARY_DIR}/mulle-status")
  execute_process(COMMAND ln -s mulle-build "${CMAKE_BINARY_DIR}/mulle-tag")
  execute_process(COMMAND ln -s mulle-build "${CMAKE_BINARY_DIR}/mulle-test")
endif(CMAKE_HOST_UNIX)


INSTALL( FILES ${SCRIPTS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "bin")


INSTALL( FILES ${SYMLINKS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "bin")

#
# CPack and project specific stuff
#
######

set( CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set( CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set( CPACK_PACKAGE_CONTACT "Nat! <nat@mulle-kybernetik.de>")
set( CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_SOURCE_DIR}/README.md")
set( CPACK_PACKAGE_DESCRIPTION_SUMMARY "🔨 Build and install tool - using bash, cmake, mulle-bootstrap")
set( CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
set( CPACK_STRIP_FILES false)
set( CPACK_DEBIAN_PACKAGE_DEPENDS "mulle-bootstrap (>= ${MULLE_BOOTSTRAP_REQ_VERSION}), cmake (>= 3.0.0)")

# stuff needed for Debian
# memo: its impossible to check for chosen generator here
#
# CPackDeb doesn't produce 100% proper debian file unfortunately
#
set( CPACK_DEBIAN_PACKAGE_HOMEPAGE "https://github.com/mulle-nat/${PROJECT_NAME}")

# stuff needed for RPM

set( CPACK_RPM_PACKAGE_VENDOR "Mulle kybernetiK")

######
#
# must be after CPACK_PACKAGE_VERSION
include( CPack)

