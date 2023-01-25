# shellcheck shell=bash
# shellcheck disable=SC2236
# shellcheck disable=SC2166
# shellcheck disable=SC2006
#
#   Copyright (c) 2021 Nat! - Mulle kybernetiK
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
MULLE_CRAFT_STYLE_SH="included"


craft::style::usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} style [options] [show|list]

   List the subfolder used for the dispensal of craft products into the
   "dependency" folder. Or show the known styles. With a style you can control,
   if a craft for the "configuration" 'Release' will overwrite a previous craft
   for 'Debug' ("style"='none') or whether both are kept side by side
   (any of the others).

   Other possibly distinctions besides "configuration" are "sdk" and 
   "platform".

Styles:
   none      : no intermediate folders
   auto      : auto is like relax, but suppresses Release in the output
   relax     : relax will not emit the platform name, if identical to host
   strict    : emit everything as two folders
   tight     : like strict but uses only one folder
   i-<style> : reverses the order of a style

Options:
   --style <s>          : dispense style (auto)
   --sdk <sdk>          : the SDK to craft with (Default)
   --platform <p>       : the platform to craft for (${MULLE_UNAME})
   --configuration <c>  : configuration to craft  (Debug)

EOF
  exit 1
}



craft::style::r_get_sdk_platform_string()
{
   log_entry "craft::style::r_get_sdk_platform_string" "$@"

   local sdk="$1"
   local platform="$2"
   local style="$3"

   [ -z "${sdk}" ]        && _internal_fail "sdk must not be empty"
   [ -z "${platform}" ]   && _internal_fail "platform must not be empty"
   [ -z "${style}" ]      && _internal_fail "style must not be empty"

   if [ "${platform}" = 'Default' ]
   then
      platform="${MULLE_UNAME}"
   fi

   case "${style}" in
      none|i-none)
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
craft::style::r_get_sdk_platform_configuration_string()
{
   log_entry "craft::style::r_get_sdk_platform_configuration_string" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   craft::style::r_get_sdk_platform_string "${sdk}" "${platform}" "${style}"
   case "${style}" in
      i-tight)
         r_concat "${configuration}" "${RVAL}" '-'
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
         r_concat "${RVAL}" "${configuration}" '-'
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


craft::style::main()
{
   log_entry "craft::style::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_SDK='Default'
   local OPTION_CONFIGURATION='Debug'
   local OPTION_STYLE='auto'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft::style::usage
         ;;

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         --style)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_STYLE="$1"
         ;;

         -*)
            craft::style::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local cmd="$1"

   [ $# -ne 0 ] && shift
   [ $# -eq 0 ] || craft::style::usage "Superflous arguments \"$*\""

   case "${cmd:-list}" in
      show)
         cat <<EOF
none
auto
relax
strict
tight
i-auto
i-relax
i-strict
i-tight
EOF
      ;;

      list)
         craft::style::r_get_sdk_platform_configuration_string "${OPTION_SDK}" \
                                                               "${OPTION_PLATFORM}" \
                                                               "${OPTION_CONFIGURATION}" \
                                                               "${OPTION_STYLE}"
         if [ -z "${RVAL}" ]
         then
            log_info "Style output is empty"
         else
            echo "${RVAL}"
         fi
      ;;

      *)
         craft::style::usage "Unknown command \"${cmd}\""
      ;;
   esac
}

