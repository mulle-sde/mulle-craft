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
MULLE_CRAFT_SEARCHPATH_SH="included"


craft_searchpath_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} searchpath [options] <framework|header|library>

   Emit a colon separated searchpath for searching libraries, headers,
   frameworks in the local dependencies and addictions. It does not include
   system headers. Use mulle-platform for finding the system searchpaths.

   Release is always a fallback for Debug.

   Example output:
      dependency/Debug/include:dependency/include:addiction/include

Options:
   --if-exists       : only add to searchpath if directory exists
   --style <style>   : adjust output to match style
   --release         : adjust output to match configuration "Release"
   --debug           : adjust output to match configuration "Debug"
   --test            : set "Test" flag

Environment:
   ADDICTION_DIR     : place to put addictions into
   DEPENDENCY_DIR    : place to put dependencies into (generally required)
   DISPENSE_STYLE    : how build productes are placed into DEPENDENCY_DIR
EOF
  exit 1
}


#
#
#
#
#
#
r_get_sdk_platform_style_string()
{
   log_entry "r_get_sdk_platform_style_string" "$@"

   local sdk="$1"
   local platform="$2"
   local style="$3"

   [ -z "${sdk}" ]        && internal_fail "sdk must not be empty"
   [ -z "${platform}" ]   && internal_fail "platform must not be empty"
   [ -z "${style}" ]      && internal_fail "style must not be empty"

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
            if [ "${platform}" = "Default" ]
            then
               RVAL=""
            else
               RVAL="${platform}"
            fi
         else
            if [ "${platform}" = "Default" ]
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
            if [ "${platform}" = "Default" ]
            then
               RVAL=""
            else
               RVAL="${platform}"
            fi
         else
            if [ "${platform}" = "Default" ]
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


craft_searchpath_main()
{
   log_entry "craft_searchpath_main" "$@"

   local OPTION_IF_EXISTS='NO'
   local OPTION_PREFIX_ONLY='NO'
   local OPTION_TEST='NO'

   local configurations
   local platforms
   local sdks
   local style

   configurations="${CONFIGURATIONS:-Debug:Release}"
   sdks="${SDKS:-Default}"
   platforms="${PLATFORMS:-Default}"
   style="${DISPENSE_STYLE:-none}"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft_searchpath_usage
         ;;

         --prefix-only)
            OPTION_PREFIX_ONLY='YES'
         ;;

         --if-exists)
            OPTION_IF_EXISTS='YES'
         ;;

         --release)
            configurations="Release"
         ;;

         --debug)
            # Release is fallback for Debug
            configurations="Debug"
         ;;

         --mulle-test)
            OPTION_MULLE_TEST='YES'
         ;;

         --configurations|--configuration)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            configurations="$1"
         ;;

         --platforms)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            platforms="$1"
         ;;

         --style)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            style="$1"
         ;;

         --sdks)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            sdks="$1"
         ;;

         -*)
            craft_searchpath_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local type="$1"

   [ -z "${type}" ] && usage "Type is missing"
   [ $# -ne 1 ] && usage "Superflous parameters \"$*\""

   local subdir

   case "${type}" in
      framework)
         subdir="Frameworks"
      ;;

      header)
         subdir="include"
      ;;

      library)
         subdir="lib"
      ;;

      *)
         usage "Unknown type \"$1\""
      ;;
   esac

   if [ "${OPTION_PREFIX_ONLY}" = 'YES' ]
   then
      subdir=""
   fi

   local configuration
   local platform
   local sdk
   local subdir

   local directory
   local paths

   configurations="${configurations}:Release"

   set -f; IFS=':'
   for configuration in ${configurations}
   do
      for platform in ${platforms}
      do
         for sdk in ${sdks}
         do
            set +f; IFS="${DEFAULT_IFS}"

            r_get_sdk_platform_configuration_style_string "${sdk}" \
                                                          "${platform}" \
                                                          "${configuration}" \
                                                          "${style}"
            directory="${RVAL}"

            r_filepath_concat "${DEPENDENCY_DIR}" "${directory}"
            r_filepath_concat "${RVAL}" "${subdir}"
            r_absolutepath "${RVAL}"

            if [ "${OPTION_IF_EXISTS}" = 'NO' ] || [  -d "${RVAL}" ]
            then
               r_add_unique_line "${paths}" "${RVAL}"
               paths="${RVAL}"
            fi

            set -f; IFS=':'
         done
      done
   done
   set +f; IFS="${DEFAULT_IFS}"

   r_filepath_concat "${ADDICTION_DIR}" "${subdir}"
   r_absolutepath "${RVAL}"
   if [ "${OPTION_IF_EXISTS}" = 'NO' ] || [  -d "${RVAL}" ]
   then
      r_add_unique_line "${paths}" "${RVAL}"
      paths="${RVAL}"
   fi

   local searchpath

   set -o noglob; IFS=$'\n'
   for directory in ${paths}
   do
      set +o noglob; IFS="${DEFAULT_IFS}"
      r_colon_concat "${searchpath}" "${directory}"
      searchpath="${RVAL}"
   done
   set +o noglob; IFS="${DEFAULT_IFS}"

   [ ! -z "${searchpath}" ] && printf "%s\n" "${searchpath}"
}

:
