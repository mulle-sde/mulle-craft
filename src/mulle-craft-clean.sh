#! /usr/bin/env bash
#
#   Copyright (c) 2017 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
#   Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   Neither the name of Mulle kybernetiK nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#
MULLE_CRAFT_CLEAN_SH="included"


build_clean_usage()
{
    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} clean [options] [style]

   Remove build directory. You can specify a variety of clean styles. The
   default is sourcetree.

Options:
   --no-dependencies : do not remove dependencies

Styles:
   all
   dependencies
   nodependencies
   project
   sourcetree

Environment:
   BUILD_DIR        : place for build products and by-products
   DEPENDENCIES_DIR : place to put dependencies into (generally required)
EOF
  exit 1
}


remove_directory()
{
   log_entry "remove_directory" "$@"

   if [ -d "$1" ]
   then
      log_verbose "Deleting ${C_RESET_BOLD}$1${C_VERBOSE}"

      rmdir_safer "$1"
   else
      log_fluff "Removal candidate \"$1\" is not present"
   fi
}


remove_directories()
{
   log_entry "remove_directories" "$@"

   while [ $# -ne 0 ]
   do
      if [ ! -z "$1" ]
      then
         remove_directory "$1"
      fi
      shift
   done
}


#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
build_clean_main()
{
   log_entry "build_clean_main" "$@"

   local OPTION_DEPENDENCIES="DEFAULT"
   local OPTION_DEPENDENCIES_BUILD_DIR

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h|-help|--help)
            build_execute_usage
         ;;

         --dependencies)
            OPTION_DEPENDENCIES="YES"
         ;;

         --no-dependencies)
            OPTION_DEPENDENCIES="NO"
         ;;

         --only-dependencies)
            OPTION_DEPENDENCIES="ONLY"
         ;;


         -b|--build-dir)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            shift

            BUILD_DIR="$1"
         ;;

         --dependencies-build-dir)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            shift

            OPTION_DEPENDENCIES_BUILD_DIR="$1"
         ;;

         -*)
            log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown option \"$1\""
            build_execute_usage
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local style

   style="$1"
   [ $# -ne 0 ] && shift

   [ $# -eq 0 ] || fail "superflous arguments \"$*\""


   local OPTION_USE_PROJECT
   local OPTION_USE_SOURCETREE

   OPTION_USE_PROJECT="NO"
   OPTION_USE_SOURCETREE="YES"

   case "${style}" in
      "sourcetree")
      ;;

      "all")
         OPTION_USE_PROJECT="YES"
         OPTION_USE_SOURCETREE="YES"
      ;;

      ""|"project")
         OPTION_USE_PROJECT="YES"
         OPTION_USE_SOURCETREE="NO"
      ;;

      "dependencies")
         OPTION_DEPENDENCIES="ONLY"
      ;;

      "nodependencies")
         OPTION_DEPENDENCIES="NO"
      ;;

      *)
         fail "unknown clean style \"$1\""
      ;;
   esac

   if [ "${OPTION_USE_PROJECT}" = "YES" -a "${OPTION_DEPENDENCIES}" != "ONLY" ]
   then
      remove_directory "${BUILD_DIR}"
   fi

   if [ "${OPTION_USE_SOURCETREE}" = "YES" ]
   then
      if [ "${OPTION_DEPENDENCIES}" != "NO" ]
      then
         remove_directory "${OPTION_DEPENDENCIES_BUILD_DIR}"
         remove_directory "${DEPENDENCIES_DIR}"
      fi
   fi
}
