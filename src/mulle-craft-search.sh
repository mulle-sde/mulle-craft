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

   Search for a craftinfo for the project or the given dependency.

Options:
   --project-dir <dir> : project directory
   --no-platform       : ignore platform specific craftinfo
   --no-local          : ignore local .mulle/etc/craft craftinfo

Environment:
   DEPENDENCY_DIR    : place to put dependencies into (generally required)
EOF
  exit 1
}


r_determine_craftinfo_dir()
{
   log_entry "r_determine_craftinfo_dir" "$@"

   #
   # upper case for the sake of sameness for ppl setting CRAFTINFO_PATH
   # in the environment ?=??
   #
   local name="$1"
   local projectdir="$2"
   local projecttype="$3"
   local allowplatform="$4"
   local allowlocal="$5"
   local configuration="$6"

   [ -z "${name}" ] && internal_fail "name must not be null"

   # replace slashes with underscores
   r_fast_basename "${name}"
   name="${RVAL}"

   local craftinfodir
   local searchpath

   if [ ! -z "${INFO_DIR}" ]
   then
      RVAL="${INFO_DIR}"
      return
   fi

   if [ ! -z "${CRAFTINFO_PATH}" ]
   then
      searchpath="`eval echo "${CRAFTINFO_PATH}"`"
   else
      case "${projecttype}" in
         "dependency")
            if [ ! -z "${DEPENDENCY_DIR}" ]
            then
               if [ ! -z "${configuration}" ]
               then
                  if [ "${allowplatform}" = 'YES' ]
                  then
                     r_colon_concat "${searchpath}" \
"${DEPENDENCY_DIR}/${configuration}/share/mulle-craft/${name}/definition.${MULLE_UNAME}"
                     searchpath="${RVAL}"
                  fi
                  r_colon_concat "${searchpath}" \
"${DEPENDENCY_DIR}/${configuration}/share/mulle-craft/${name}/definition"
                  searchpath="${RVAL}"
               fi

               if [ "${allowplatform}" = 'YES' ]
               then
                  r_colon_concat "${searchpath}" \
"${DEPENDENCY_DIR}/share/mulle-craft/${name}/definition.${MULLE_UNAME}"
                  searchpath="${RVAL}"
               fi
               r_colon_concat "${searchpath}" \
"${DEPENDENCY_DIR}/share/mulle-craft/${name}/definition"
               searchpath="${RVAL}"
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
         if [ "${allowlocal}" = 'YES' ]
         then
            if [ "${allowplatform}" = 'YES' ]
            then
               r_colon_concat "${searchpath}" \
                              "${projectdir}/.mulle/etc/craft/definition.${MULLE_UNAME}"
               searchpath="${RVAL}"
            fi
            r_colon_concat "${searchpath}" "${projectdir}/.mulle/etc/craft/definition"
            searchpath="${RVAL}"
         fi
      fi
   fi

   log_fluff "Craftinfo search order: ${searchpath}"

   set -f ; IFS=":"
   for craftinfodir in ${searchpath}
   do
      set +f ; IFS="${DEFAULT_IFS}"
      if [ ! -z "${craftinfodir}" ] && [ -d "${craftinfodir}" ]
      then
         log_fluff "Craftinfo directory \"${craftinfodir}\" found"
         RVAL="${craftinfodir}"
         return 0
      fi
   done
   set +f ; IFS="${DEFAULT_IFS}"

   log_fluff "No craftinfo found"

   RVAL=""
   return 2
}


build_search_main()
{
   log_entry "build_common" "$@"

   local OPTION_PROJECT_DIR
   local OPTION_PLATFORM='YES'
   local OPTION_LOCAL='YES'

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

         --no-platform|--no-platform-craftinfo)
            OPTION_PLATFORM='NO'
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL='NO'
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
         r_fast_basename "${PWD}"
         name="${RVAL}"
      fi

	   r_determine_craftinfo_dir "${name}" \
                                "${OPTION_PROJECT_DIR:-${PWD}}" \
                                "mainproject" \
                                "${OPTION_GLOBAL}"
	else
		if [ -z "${OPTION_PROJECT_DIR}" ]
		then
			fail "Specify --project-dir <dir> for dependency \"$1\""
		fi

	   r_determine_craftinfo_dir "$1" \
                              "${OPTION_PROJECT_DIR}" \
                              "dependency" \
                              "${OPTION_PLATFORM}" \
                              "${OPTION_LOCAL}"
	fi

   [ ! -z "${RVAL}" ] && echo "${RVAL}"
}
