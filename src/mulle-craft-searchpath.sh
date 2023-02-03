# shellcheck shell=bash
# shellcheck disable=SC2236
# shellcheck disable=SC2166
# shellcheck disable=SC2006
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
MULLE_CRAFT_SEARCHPATH_SH='included'


craft::searchpath::usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} searchpath [options] <framework|header|library>

   Emit a colon separated searchpath for searching libraries, headers,
   frameworks in the local dependencies and addictions. It does not include
   system headers. Use mulle-platform for finding the system searchpaths.

   Used by build scripts to determine proper search paths.

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
   MULLE_CRAFT_DISPENSE_STYLE    : how build productes are placed into DEPENDENCY_DIR
EOF
  exit 1
}


craft::searchpath::main()
{
   log_entry "craft::searchpath::main" "$@"

   local OPTION_IF_EXISTS='NO'
   local OPTION_PREFIX_ONLY='NO'
   local OPTION_TEST='NO'

   local configurations
   local platforms
   local sdks
   local style

   configurations="${MULLE_CRAFT_CONFIGURATIONS:-Debug:Release}"
   sdks="${MULLE_CRAFT_SDKS:-Default}"
   platforms="${MULLE_CRAFT_PLATFORMS:-${MULLE_UNAME}}"
   style="${MULLE_CRAFT_DISPENSE_STYLE:-auto}"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft::searchpath::usage
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
            [ $# -eq 1 ] && craft::searchpath::usage "Missing argument to \"$1\""
            shift

            configurations="$1"
         ;;

         --platforms)
            [ $# -eq 1 ] && craft::searchpath::usage "Missing argument to \"$1\""
            shift

            platforms="$1"
         ;;

         --style)
            [ $# -eq 1 ] && craft::searchpath::usage "Missing argument to \"$1\""
            shift

            style="$1"
         ;;

         --sdks)
            [ $# -eq 1 ] && craft::searchpath::usage "Missing argument to \"$1\""
            shift

            sdks="$1"
         ;;

         -*)
            craft::searchpath::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local type="$1"

   [ -z "${type}" ] && craft::searchpath::usage "Type is missing"
   [ $# -ne 1 ] && craft::searchpath::usage "Superflous parameters \"$*\""

   include "craft::path"
   include "craft::style"

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
         craft::searchpath::usage "Unknown type \"$1\""
      ;;
   esac

   if [ "${OPTION_PREFIX_ONLY}" = 'YES' ]
   then
      subdir=""
   fi

   configurations="${configurations}:Release"

   local configuration
   local platform
   local sdk
   local directory
   local paths

   .foreachpath configuration in ${configurations}
   .do
      .foreachpath platform in ${platforms}
      .do
         .foreachpath sdk in ${sdks}
         .do
            craft::style::r_get_sdk_platform_configuration_string "${sdk}" \
                                                                  "${platform}" \
                                                                  "${configuration}" \
                                                                  "${style}"
            directory="${RVAL}"

            r_filepath_concat "${DEPENDENCY_DIR}" "${directory}"
            r_filepath_concat "${RVAL}" "${subdir}"
            r_absolutepath "${RVAL}"

            if [ "${OPTION_IF_EXISTS}" = 'YES' ] && [ ! -d "${RVAL}" ]
            then
               log_verbose "Directory \"${RVAL}\" is not in the searchpath because it doesn't exist"
            else
               r_add_unique_line "${paths}" "${RVAL}"
               paths="${RVAL}"
            fi
         .done
      .done
   .done

   r_filepath_concat "${ADDICTION_DIR}" "${subdir}"
   r_absolutepath "${RVAL}"

   if [ "${OPTION_IF_EXISTS}" = 'YES' ] && [ ! -d "${RVAL}" ]
   then
      log_verbose "Directory \"${RVAL}\" is not in the searchpath because it doesn't exist"
   else
      r_add_unique_line "${paths}" "${RVAL}"
      paths="${RVAL}"
   fi

   local searchpath

   .foreachline directory in ${paths}
   .do
      r_colon_concat "${searchpath}" "${directory}"
      searchpath="${RVAL}"
   .done

   [ ! -z "${searchpath}" ] && printf "%s\n" "${searchpath}"
}

:
