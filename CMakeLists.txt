cmake_minimum_required( VERSION 3.15)

project( mulle-craft VERSION 3.3.3 LANGUAGES NONE)

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
                 WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                 OUTPUT_VARIABLE MULLE_CRAFT_VERSION
                 OUTPUT_STRIP_TRAILING_WHITESPACE)
message( STATUS "MULLE_CRAFT_VERSION is ${MULLE_CRAFT_VERSION} according to mulle-craft")


set( PROJECT_VERSION "${MULLE_CRAFT_VERSION}")


set( SCRIPTS
   mulle-craft
)


file( GLOB LIBRARY_SCRIPTS
   "src/*.sh"
)



install( FILES ${SCRIPTS}
   PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
               GROUP_EXECUTE GROUP_READ
               WORLD_EXECUTE WORLD_READ
   DESTINATION "bin"
)


install( FILES ${LIBRARY_SCRIPTS}
   PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
               GROUP_EXECUTE GROUP_READ
               WORLD_EXECUTE WORLD_READ
   DESTINATION "libexec/mulle-craft"
)




######
#
# must be after CPACK_PACKAGE_VERSION
include( CMakePackage.cmake)
include( CPack)
