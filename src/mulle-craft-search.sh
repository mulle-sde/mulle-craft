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
MULLE_CRAFT_SEARCH_SH="included"


build_search_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} search [options] [dependency]

   Search for a buildinfo for the project or the given dependency.

Options:
   --project-dir <dir> : project directory

Environment:
   DEPENDENCY_DIR    : place to put dependencies into (generally required)
EOF
  exit 1
}


determine_buildinfo_dir()
{
   log_entry "determine_buildinfo_dir" "$@"

   #
   # upper case for the sake of sameness for ppl setting BUILDINFO_PATH
   # in the environment ?=??
   #
   local name="$1"
   local projectdir="$2"
   local projecttype="$3"

   [ -z "${name}" ] && internal_fail "name must not be null"

   local buildinfodir
   local searchpath

   if [ ! -z "${INFO_DIR}" ]
   then
      echo "${INFO_DIR}"
      return
   fi

   if [ ! -z "${BUILDINFO_PATH}" ]
   then
      searchpath="`eval echo "${BUILDINFO_PATH}"`"
   else
      case "${projecttype}" in
         "dependency")
            # the directory being edited with mulle-sde dependency definition
            #            searchpath="`colon_concat "${searchpath}" "buildinfo/${name}/mulle-make.${MULLE_UNAME}" `"
            #            searchpath="`colon_concat "${searchpath}" "buildinfo/${name}/mulle-make" `"
            # stuff installed by subprojects
            if [ ! -z "${DEPENDENCY_DIR}" ]
            then
               searchpath="`colon_concat "${searchpath}" "${DEPENDENCY_DIR}/share/mulle-craft/${name}.${MULLE_UNAME}" `"
               searchpath="`colon_concat "${searchpath}" "${DEPENDENCY_DIR}/share/mulle-craft/${name}" `"
            fi
         ;;

         "mainproject")
           [ -z "${projectdir}" ] && internal_fail "projectdir not set"
         ;;

         *)
            internal_fail "Unknown project type \"${projecttype}\""
         ;;
      esac

      if [ ! -z "${projectdir}" ]
      then
         searchpath="`colon_concat "${searchpath}" "${projectdir}/.mulle-make.${MULLE_UNAME}" `"
         searchpath="`colon_concat "${searchpath}" "${projectdir}/.mulle-make" `"
      fi
   fi

   log_fluff "Buildinfo searchpath: ${searchpath}"

   set -f ; IFS=":"
   for buildinfodir in ${searchpath}
   do
      set +f ; IFS="${DEFAULT_IFS}"
      if [ ! -z "${buildinfodir}" ] && [ -d "${buildinfodir}" ]
      then
         log_verbose "Info directory \"${buildinfodir}\" found"
         echo "${buildinfodir}"
         return 0
      fi
   done
   set +f ; IFS="${DEFAULT_IFS}"

   log_fluff "No buildinfo found"

   return 2
}


build_search_main()
{
   log_entry "build_common" "$@"

   local OPTION_PROJECT_DIR

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            build_search_usage
         ;;

         -d|--project-dir)
            [ $# -eq 1 ] && build_search_usage "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_DIR="$1"  # could be global env
         ;;

         -*)
            build_search_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done


   if [ $# -eq 0 ]
   then
      local name

      name="${PROJECT_NAME}"
      if [ -z "${PROJECT_NAME}" ]
      then
         name="`fast_basename "${PWD}"`"
      fi

	   determine_buildinfo_dir "${name}" "${OPTION_PROJECT_DIR:-${PWD}}" "mainproject"
	else
		if [ -z "${OPTION_PROJECT_DIR}" ]
		then
			fail "Specify --project-dir <dir> for dependency \"$1\""
		fi

	   determine_buildinfo_dir "$1" "${OPTION_PROJECT_DIR}" "dependency"
	fi
}
