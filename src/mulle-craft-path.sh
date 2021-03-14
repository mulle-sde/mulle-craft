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
MULLE_CRAFT_PATH_SH="included"


craft_craftorder_searchpath_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} craftorder-searchpath [options] <framework|header|library>

   Emits the craftinfo searchpath.

Options:
   --style <style>   : adjust output to match style
   --release         : adjust output to match configuration "Release"
   --debug           : adjust output to match configuration "Debug"

Environment:
   DEPENDENCY_DIR    : place to put dependencies into (generally required)
   MULLE_CRAFT_DISPENSE_STYLE    : how build productes are placed into DEPENDENCY_DIR
EOF
  exit 1
}



craft_craftorder_search_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} search [options] [dependency]

   Search for a craftinfo of the project or a given dependency.

   TODO: explain searchpath.

Options:
   --project-dir <dir> : project directory
   --no-platform       : ignore platform specific craftinfo
   --no-local          : ignore local .mulle/etc/craft craftinfo

Environment:
   DEPENDENCY_DIR    : place to put dependencies into (generally required)
EOF
  exit 1
}


r_get_sdk_platform_style_string()
{
   log_entry "r_get_sdk_platform_style_string" "$@"

   local sdk="$1"
   local platform="$2"
   local style="$3"

   [ -z "${sdk}" ]        && internal_fail "sdk must not be empty"
   [ -z "${platform}" ]   && internal_fail "platform must not be empty"
   [ -z "${style}" ]      && internal_fail "style must not be empty"

   if [ "${platform}" = 'Default' ]
   then
      platform="${MULLE_UNAME}"
   fi

   case "${style}" in
      none)
         RVAL=
      ;;

      strict)
         RVAL="${sdk}-${platform}"
      ;;

      i-strict)
         RVAL="${platform}-${sdk}"
      ;;

      auto|relax|tight)
         if [ "${sdk}" = "Default" ]
         then
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL=""
            else
               RVAL="${platform}"
            fi
         else
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL="${sdk}"
            else
               RVAL="${sdk}-${platform}"
            fi
         fi
      ;;

      i-auto|i-relax|i-tight)
         if [ "${sdk}" = "Default" ]
         then
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL=""
            else
               RVAL="${platform}"
            fi
         else
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL="${sdk}"
            else
               RVAL="${platform}-${sdk}"
            fi
         fi
      ;;


      *)
         fail "Unknown dispense style \"${style}\""
      ;;
   esac
}


#
# Note:  build directories are always like relax dispense-style
#        this is relevant for dispensing
#
# TODO: make style a formatter, so ppl can chose arbitrarily
#
r_get_sdk_platform_configuration_style_string()
{
   log_entry "r_get_sdk_platform_configuration_style_string" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   r_get_sdk_platform_style_string "${sdk}" "${platform}" "${style}"
   case "${style}" in
      i-tight)
         r_filepath_concat "${configuration}-${RVAL}"
      ;;

      i-strict|i-relax)
         r_filepath_concat "${configuration}" "${RVAL}"
      ;;

      i-auto)
         if [ "${configuration}" != "Release" ]
         then
            r_filepath_concat "${configuration}" "${RVAL}"
         fi
      ;;

      tight)
         r_filepath_concat "${RVAL}-${configuration}"
      ;;

      strict|relax)
         r_filepath_concat "${RVAL}" "${configuration}"
      ;;

      auto)
         if [ "${configuration}" != "Release" ]
         then
            r_filepath_concat "${RVAL}" "${configuration}"
         fi
      ;;
   esac
}


r_concat_craftinfo_searchpath()
{
   log_entry "r_concat_craftinfo_searchpath" "$@"

   local searchpath="$1"
   local directory="$2"
   local platform="$3"
   local allowplatform="$4"

   if [ "${allowplatform}" != 'NO' ]   # empty is OK
   then
      if [ "${platform}" = 'Default' ]
      then
         platform="${MULLE_UNAME}"
      fi

      r_colon_concat "${searchpath}" \
                     "${directory}/definition.${platform}"
      searchpath="${RVAL}"
   fi
   r_colon_concat "${searchpath}" "${directory}/definition"
}


r_determine_craftinfo_searchpath()
{
   log_entry "r_determine_craftinfo_searchpath" "$@"

   [ $# -eq 9 ] || internal_fail "api error"

   local name="${1:-unknown}"
   local projectdir="${2:-${PWD}}"
   local projecttype="${3:-mainproject}"
   local allowplatform="${4:-YES}"
   local allowlocal="${5:-YES}"
   local platform="${6:-Default}"
   local configuration="${7:-Release}"
   local dependencydir="${8:-dependency}"
   local subdir="$9"

   local directory
   local depsubdir
   local searchpath

   case "${projecttype}" in
      "dependency")
         if [ ! -z "${dependencydir}" ]
         then
            if [ ! -z "${configuration}" ]
            then
               r_filepath_concat "${dependencydir}" "${subdir}"
               depsubdir="${RVAL}"

               directory="${depsubdir}/share/mulle-craft/${name}"
               r_concat_craftinfo_searchpath "${searchpath}" \
                                             "${directory}" \
                                             "${platform}" \
                                             "${allowplatform}"
               searchpath="${RVAL}"
            fi

            directory="${dependencydir}/share/mulle-craft/${name}"
            r_concat_craftinfo_searchpath "${searchpath}" \
                                          "${directory}" \
                                          "${platform}" \
                                          "${allowplatform}"
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

   if [ -z "${projectdir}" -o "${allowlocal}" = 'NO' ]
   then
      RVAL="${searchpath}"
      return
   fi

   directory="${projectdir}/.mulle/etc/craft"
   r_concat_craftinfo_searchpath "${searchpath}" \
                                 "${directory}" \
                                 "${platform}" \
                                 "${allowplatform}"
   searchpath="${RVAL}"

   directory="${projectdir}/.mulle/share/craft"
   r_concat_craftinfo_searchpath "${searchpath}" \
                                 "${directory}" \
                                 "${platform}" \
                                 "${allowplatform}"
}



r_determine_craftinfo_dir()
{
   log_entry "r_determine_craftinfo_dir" "$@"

   #
   # upper case for the sake of sameness for ppl setting MULLE_CRAFT_CRAFTINFO_PATH
   # in the environment ?=??
   #
   [ $# -eq 9 ] || internal_fail "api error"

   local name="${1:-unknown}"
   local projectdir="${2:-${PWD}}"
   local projecttype="${3:-mainproject}"
   local allowplatform="${4:-YES}"
   local allowlocal="${5:-YES}"
   local sdk="${6:-Default}"
   local platform="${7:-Default}"
   local configuration="${8:-Release}"
   local style="${9:-none}"

   #
   # hmm, how does this work for multiple crafts. It can't I guess
   #      so only use for mainproject
   #
   if [ ! -z "${INFO_DIR}" -a "${projecttype}" = "mainproject" ]
   then
      log_fluff "Using definition defined by commandline (or environment INFO_DIR)"
      RVAL="${INFO_DIR}"
      return
   fi

   if [ -z "${MULLE_CRAFT_SEARCHPATH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-searchpath.sh" || exit 1
   fi

   local subdir

   r_get_sdk_platform_configuration_style_string "${sdk}" \
                                                 "${platform}" \
                                                 "${configuration}" \
                                                 "${style}"
   subdir="${RVAL}"

   r_basename "${name}"
   name="${RVAL}"

   [ -z "${name}" ] && internal_fail "name is empty"

   local craftinfodir
   local searchpath

   if [ ! -z "${MULLE_CRAFT_CRAFTINFO_PATH}" ]
   then
      r_expanded_string "${MULLE_CRAFT_CRAFTINFO_PATH}"
      searchpath="${RVAL}"
   else
     r_determine_craftinfo_searchpath "${name}" \
                                      "${projectdir}" \
                                      "${projecttype}" \
                                      "${allowplatform}" \
                                      "${allowlocal}" \
                                      "${platform}" \
                                      "${configuration}" \
                                      "${DEPENDENCY_DIR}" \
                                      "${subdir}"
      searchpath="${RVAL}"
   fi

   log_fluff "Craftinfo search order: ${searchpath}"

   set -f ; IFS=':'
   for craftinfodir in ${searchpath}
   do
      set +f; IFS="${DEFAULT_IFS}"
      if [ ! -z "${craftinfodir}" ] && [ -d "${craftinfodir}" ]
      then
         log_fluff "Craftinfo directory \"${craftinfodir}\" found"
         RVAL="${craftinfodir}"
         return 0
      fi
   done
   set +f; IFS="${DEFAULT_IFS}"

   log_fluff "No craftinfo \"${name}\" found"

   RVAL=""
   return 2
}



craft_craftorder_searchpath_main()
{
   log_entry "craft_craftorder_searchpath_main" "$@"

   local OPTION_PROJECT_DIR="${PWD}"
   local OPTION_PROJECT_TYPE="mainproject"
   local OPTION_ALLOW_LOCAL='YES'
   local OPTION_ALLOW_PROJECT='YES'
   local OPTION_NAME
   local OPTION_CONFIGURATION="Release"
   local OPTION_SDK="Default"
   local OPTION_PLATFORM="Default"
   local OPTION_STYLE="none"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft_craftorder_searchpath_usage
         ;;

         --release)
            OPTION_CONFIGURATION="Release"
         ;;

         --debug)
            # Release is fallback for Debug
            OPTION_CONFIGURATION="Debug"
         ;;

         --dependency)
            OPTION_PROJECT_TYPE="dependency"
         ;;

         --project)
            OPTION_PROJECT_TYPE="mainproject"
         ;;

         --no-local)
            OPTION_ALLOW_LOCAL="NO"
         ;;

         --no-platform)
            OPTION_ALLOW_PLATFORM="NO"
         ;;

         --name)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_NAME="$1"
         ;;

         --project-dir)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_DIR="$1"
         ;;


         --project-type)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_TYPE="$1"
         ;;

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         --style)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_STYLE="$1"
         ;;

         -*)
            craft_craftorder_searchpath_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   OPTION_PROJECT_DIR="${OPTION_PROJECT_DIR:-${MULLE_VIRTUAL_ROOT}}"
   OPTION_PROJECT_DIR="${OPTION_PROJECT_DIR:-${PWD}}"
   OPTION_NAME="${OPTION_NAME:-`basename -- "${OPTION_PROJECT_DIR}"`}"

   [ $# -ne 0 ] && craft_craftorder_searchpath_usage "Superflous parameters \"$*\""

   log_info "${OPTION_SDK}-${OPTION_PLATFORM}/${OPTION_CONFIGURATION}"

   r_get_sdk_platform_configuration_style_string "${OPTION_SDK}" \
                                                 "${OPTION_PLATFORM}" \
                                                 "${OPTION_CONFIGURATION}" \
                                                 "${OPTION_STYLE}"
   subdir="${RVAL}"

   r_determine_craftinfo_searchpath "${OPTION_NAME}" \
                                    "${OPTION_PROJECT_DIR}" \
                                    "${OPTION_PROJECT_TYPE}" \
                                    "${OPTION_ALLOW_PLATFORM}" \
                                    "${OPTION_ALLOW_LOCAL}" \
                                    "${OPTION_PLATFORM}" \
                                    "${OPTION_CONFIGURATION}" \
                                    "${DEPENDENCY_DIR}" \
                                    "${subdir}"
   printf "%s\n" "${RVAL}"
}



craft_craftorder_search_main()
{
   log_entry "craft_craftorder_search_main" "$@"

   local OPTION_PROJECT_DIR
   local OPTION_PLATFORM_CRAFTINFO='YES'
   local OPTION_LOCAL_CRAFTINFO='YES'
   local OPTION_PLATFORM='Default'
   local OPTION_SDK='Default'
   local OPTION_CONFIGURATION='Release'
   local OPTION_STYLE='auto'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft_craftorder_search_usage
         ;;

         -d|--project-dir)
            [ $# -eq 1 ] && craft_craftorder_search_usage "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_DIR="$1"  # could be global env
         ;;

         --no-platform|--no-platform-craftinfo)
            OPTION_PLATFORM_CRAFTINFO='NO'
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL_CRAFTINFO='NO'
         ;;

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         --style)
            [ $# -eq 1 ] && craft_craftorder_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_STYLE="$1"
         ;;

         -*)
            craft_craftorder_search_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local rval

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
                                "${OPTION_PROJECT_DIR}" \
                                "mainproject" \
                                "${OPTION_PLATFORM_CRAFTINFO}" \
                                "${OPTION_LOCAL_CRAFTINFO}" \
                                "${OPTION_SDK}" \
                                "${OPTION_PLATFORM}" \
                                "${OPTION_CONFIGURATION}" \
                                "${OPTION_STYLE}"
      rval=$?
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
                                "${OPTION_SDK}" \
                                "${OPTION_PLATFORM}" \
                                "${OPTION_CONFIGURATION}" \
                                "${OPTION_STYLE}"
      rval=$?
	fi

   [ "${rval}" -eq 0 ] && printf "%s\n" "${RVAL}"

   return $rval
}
