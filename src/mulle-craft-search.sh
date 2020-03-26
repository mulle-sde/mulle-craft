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


craft_search_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} search [options] [dependency]

   Search for a craftinfo of the project or a given dependency.

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
   [ $# -eq 9 ] || internal_fail "api error"

   local name="$1"
   local projectdir="$2"
   local projecttype="$3"
   local allowplatform="$4"
   local allowlocal="$5"
   local sdk="$6"
   local platform="$7"
   local configuration="$8"
   local style="$9"

   [ -z "${name}" ] && internal_fail "name must not be null"

   if [ -z "${MULLE_CRAFT_SEARCHPATH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-searchpath.sh" || exit 1
   fi

   local extension

   r_get_sdk_platform_configuration_style_string "${sdk}" "${platform}" "${configuration}" "${style}"
   subdir="${RVAL}"

   if [ "${platform}" != "Default" ]
   then
      extension="${platform}"
   else
      extension="${MULLE_UNAME}"
   fi

   r_basename "${name}"
   name="${RVAL}"

   [ -z "${name}" ] && internal_fail "name is empty"

   local craftinfodir
   local searchpath

   if [ ! -z "${INFO_DIR}" ]
   then
      log_fluff "Using definition defined by commandline (or environment INFO_DIR)"
      RVAL="${INFO_DIR}"
      return
   fi

   if [ ! -z "${CRAFTINFO_PATH}" ]
   then
      eval printf -v CRAFTINFO_PATH "\"%s\"" "\"${CRAFTINFO_PATH}\""
   else
      case "${projecttype}" in
         "dependency")
            if [ ! -z "${DEPENDENCY_DIR}" ]
            then
               local directory

               if [ ! -z "${configuration}" ]
               then
                  local depsubdir

                  r_filepath_concat "${DEPENDENCY_DIR}" "${subdir}"
                  depsubdir="${RVAL}"

                  directory="${depsubdir}/share/mulle-craft/${name}"
                  if [ "${allowplatform}" = 'YES' ]
                  then
                     r_colon_concat "${searchpath}" "${directory}/definition.${extension}"
                     searchpath="${RVAL}"
                  fi
                  r_colon_concat "${searchpath}" "${directory}/definition"
                  searchpath="${RVAL}"
               fi

               directory="${DEPENDENCY_DIR}/share/mulle-craft/${name}"
               if [ "${allowplatform}" = 'YES' ]
               then
                  r_colon_concat "${searchpath}" "${directory}/definition.${extension}"
                  searchpath="${RVAL}"
               fi
               r_colon_concat "${searchpath}" "${directory}/definition"
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
                              "${projectdir}/.mulle/etc/craft/definition.${extension}"
               searchpath="${RVAL}"
            fi
            r_colon_concat "${searchpath}" "${projectdir}/.mulle/etc/craft/definition"
            searchpath="${RVAL}"
         fi
      fi
   fi

   log_fluff "Craftinfo search order: ${searchpath}"

   set -f ; IFS=':'
   for craftinfodir in ${searchpath}
   do
      set +o noglob; IFS="${DEFAULT_IFS}"
      if [ ! -z "${craftinfodir}" ] && [ -d "${craftinfodir}" ]
      then
         log_fluff "Craftinfo directory \"${craftinfodir}\" found"
         RVAL="${craftinfodir}"
         return 0
      fi
   done
   set +o noglob; IFS="${DEFAULT_IFS}"

   log_fluff "No craftinfo \"${name}\" found"

   RVAL=""
   return 4
}


craft_search_main()
{
   log_entry "craft_search_main" "$@"

   local OPTION_PROJECT_DIR
   local OPTION_PLATFORM_CRAFTINFO='YES'
   local OPTION_LOCAL_CRAFTINFO='YES'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft_search_usage
         ;;

         -d|--project-dir)
            [ $# -eq 1 ] && craft_search_usage "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_DIR="$1"  # could be global env
         ;;

         --no-platform|--no-platform-craftinfo)
            OPTION_PLATFORM_CRAFTINFO='NO'
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL_CRAFTINFO='NO'
         ;;

         -*)
            craft_search_usage "Unknown option \"$1\""
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
         r_basename "${PWD}"
         name="${RVAL}"
      fi

	   r_determine_craftinfo_dir "${name}" \
                                "${OPTION_PROJECT_DIR:-${PWD}}" \
                                "mainproject" \
                                "${OPTION_PLATFORM_CRAFTINFO}" \
                                "${OPTION_LOCAL_CRAFTINFO}" \
                                "${sdk:-Default}" \
                                "${platform:-Default}" \
                                "${configuration:-Release}" \
                                "${style:-auto}"

	else
		if [ -z "${OPTION_PROJECT_DIR}" ]
		then
			fail "Specify --project-dir <dir> for dependency \"$1\""
		fi

	   r_determine_craftinfo_dir "$1" \
                                "${OPTION_PROJECT_DIR}" \
                                "dependency" \
                                "${OPTION_PLATFORM_CRAFTINFO}" \
                                "${OPTION_LOCAL_CRAFTINFO}" \
                                "${sdk:-Default}" \
                                "${platform:-Default}" \
                                "${configuration:-Release}" \
                                "${style:-auto}"
	fi

   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}
