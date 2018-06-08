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
   [ "$#" -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} clean [options] [name]*

   Remove build products. By default BUILD_DIR is removed, which will
   rebuild everything. You can also specify the names of the projects to clean
   and rebuild. There are three special names: "all", "dependency", "project".

Options:
   -b <dir>         : specify build directory

Names:
   all              : clean build folder
   dependency       : clean dependency folder
   project          : clean main project

Environment:
   BUILD_DIR        : place for build products and by-products
   DEPENDENCY_DIR   : place to put dependencies into (generally required)
EOF
  exit 1
}


remove_directory()
{
   log_entry "remove_directory" "$@"

   if [ -d "$1" ]
   then
      rmdir_safer "$1"
   else
      log_fluff "Clean candidate \"$1\" is not present"
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

   local OPTION_DEPENDENCY="DEFAULT"
   local OPTION_SOURCETREE_BUILD_DIR

   while :
   do
      case "$1" in
         -h*|--help|help)
            build_clean_usage
         ;;

         -b|--build-dir)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            BUILD_DIR="$1"
         ;;

         --dependency-build-dir)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_DEPENDENCY_BUILD_DIR="$1"
         ;;

         -*)
            build_clean_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   if [ -z "${BUILD_DIR}" ]
   then
      fail "Unknown build directory, specify with -b"
   fi

   if [ $# -eq 0 ]
   then
      log_verbose "Cleaning \"${BUILD_DIR}\" directory"

      remove_directory "${BUILD_DIR}"
      return $?
   fi

#  # shellcheck source=src/mulle-craft-execute.sh
#  if [ -z "${MULLE_CRAFT_EXECUTE_SH}" ]
#  then
#     . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-execute.sh"
#  fi

   # centralize this into mulle-craft-environment.sh

   local DEPENDENCY_BUILD_DIR
   local donefile
   local escaped

   DEPENDENCY_BUILD_DIR="${OPTION_DEPENDENCY_BUILD_DIR:-${BUILD_DIR}/.buildorder}"
   donefile="${DEPENDENCY_BUILD_DIR}/.mulle-craft-built"

   while :
   do
      case "$1" in
         "dependency")
            log_verbose "Cleaning \"${DEPENDENCY_DIR}\" directory"

            remove_directory "${DEPENDENCY_DIR}"
            remove_directory "${DEPENDENCY_BUILD_DIR}"
         ;;

         "build")
            log_verbose "Cleaning \"build\""

            remove_directory "${BUILD_DIR}"
            return
         ;;

         "project")
            log_verbose "Cleaning project"

            for i in "${BUILD_DIR}"/*
            do
               if [ -d "${i}" ]
               then
                  remove_directory "${i}"
               fi
            done
         ;;

         "")
            break
         ;;

         *)
            log_verbose "Cleaning \"${1}\" dependency"

            remove_directory "${DEPENDENCY_BUILD_DIR}/$1"
            escaped="`escaped_sed_pattern "$1"`"
            if [ -f "${donefile}" ]
            then
               inplace_sed "/${escaped};/d" "${donefile}"
            fi
         ;;
      esac

      shift
   done
}
