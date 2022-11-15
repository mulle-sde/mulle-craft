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
MULLE_CRAFT_DONEFILE_SH="included"


craft::donefile::usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} donefile [options] [command]

   Show the contents and location of the "donefiles". These files remember
   the dependencies, that have been built completely. There may exist
   several donefile for each sdk-platform-configuration triple.

Options:
   --configuration <c>  : configuration used for craft (Debug)
   --no-cat             : don't show contents of donefiles
   --no-local           : don't show local donefile
   --no-shared          : don't show shared donefile
   --platform <p>       : the platform used for craft  (${MULLE_UNAME})
   --sdk <sdk>          : the SDK used for craft (Default)

Commands:
   cat                  : show contents
   list                 : list local donefiles (default)

EOF
  exit 1
}


craft::donefile::r_shared_donefile()
{
   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   RVAL="${ADDICTION_DIR}/etc/craftorder-${sdk}--${platform}--${configuration}"
}


craft::donefile::list_shared_donefiles()
{
   if [ -d "${ADDICTION_DIR}/etc" ]
   then
   (
      cd "${ADDICTION_DIR}/etc"
      shell_enable_nullglob
      ls -1 craftorder-*--*--*
   )
   fi
}


craft::donefile::r_donefile()
{
   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   RVAL="${DEPENDENCY_DIR}/etc/craftorder-${sdk}--${platform}--${configuration}"
}


craft::donefile::list_donefiles()
{
   if [ -d "${DEPENDENCY_DIR}/etc" ]
   then
   (
      cd "${DEPENDENCY_DIR}/etc"
      shell_enable_nullglob
      ls -1 craftorder-*--*--*
   )
   fi
}


#   local _donefile
#   local _shared_donefile
craft::donefile::__have_donefiles()
{
   log_entry "craft::donefile::__have_donefiles" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   #
   # the donefile is stored in a different place then the
   # actual buildir because that's to be determined later
   # at least for now
   #
   craft::donefile::r_shared_donefile "${sdk}" "${platform}" "${configuration}"
   _shared_donefile="${RVAL}"

   craft::donefile::r_donefile "${sdk}" "${platform}" "${configuration}"
   _donefile="${RVAL}"

   local have_a_donefile

   have_a_donefile="NO"
   if [ -f "${_donefile}" ]
   then
      log_fluff "A donefile \"${_donefile#"${MULLE_USER_PWD}/"}\" is present"
      have_a_donefile='YES'
      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_setting "donefile: `cat "${_donefile}"`"
      fi
   else
      r_mkdir_parent_if_missing "${_donefile}"
   fi

   if [ -f "${_shared_donefile}" ]
   then
      log_verbose "A shared donefile \"${_shared_donefile#"${MULLE_USER_PWD}/"}\" is present"
      have_a_donefile='YES'

      log_setting "shared donefile: `cat "${_shared_donefile}"`"
   else
      log_fluff "There is no shared donefile \"${_shared_donefile#"${MULLE_USER_PWD}/"}\""
   fi

   [ "${have_a_donefile}" = 'YES' ]
}


craft::donefile::main()
{
   log_entry "craft::donefile::main" "$@"

   local OPTION_PLATFORM='Default'
   local OPTION_SDK='Default'
   local OPTION_CONFIGURATION='Debug'
   local OPTION_LOCAL='YES'
   local OPTION_SHARED='YES'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft::donefile::usage
         ;;

         --local)
            OPTION_LOCAL='YES'
         ;;

         --no-local)
            OPTION_LOCAL='NO'
         ;;

         --shared)
            OPTION_SHARED='YES'
         ;;

         --no-shared)
            OPTION_SHARED='NO'
         ;;

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft::donefile::usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft::donefile::usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft::donefile::usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         -*)
            craft::donefile::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local cmd="$1"

   [ $# -ne 0 ] && shift

   cmd="${cmd:-list}"

   local donefile
   local shared_donefile

   case "${cmd}" in
      'cat'|'echo')
         OPTION_PLATFORM="${OPTION_PLATFORM:-Default}"
         OPTION_SDK="${OPTION_SDK:-Default}"
         OPTION_CONFIGURATION="${OPTION_CONFIGURATION:-Debug}"

         craft::donefile::r_donefile "${OPTION_SDK}" "${OPTION_PLATFORM}" "${OPTION_CONFIGURATION}"
         donefile="${RVAL}"

         craft::donefile::r_shared_donefile "${OPTION_SDK}" "${OPTION_PLATFORM}" "${OPTION_CONFIGURATION}"
         shared_donefile="${RVAL}"
      ;;


      'list')
         if [ "${OPTION_LOCAL}" = 'YES' ]
         then
            log_info "Donefiles"
            craft::donefile::list_donefiles "${OPTION_SDK}" "${OPTION_PLATFORM}" "${OPTION_CONFIGURATION}"
         fi

         if [ "${OPTION_SHARED}" = 'YES' ]
         then
            log_info "Shared donefiles"
            craft::donefile::list_shared_donefiles "${OPTION_SDK}" "${OPTION_PLATFORM}" "${OPTION_CONFIGURATION}"
         fi
         return $?
      ;;

      *)
         craft::donefile::usage "Unknown command \"${cmd}\""
      ;;
   esac

   case "${cmd}" in
      'echo')
         if [ "${OPTION_LOCAL}" = 'YES' ]
         then
            log_info "Donefile"
            echo "${donefile}"
         fi

         if [ "${OPTION_SHARED}" = 'YES' ]
         then
            log_info "Shared donefile"
            echo "${shared_donefile}"
         fi
         return $?
      ;;
   esac

   local have_output

   if [ "${OPTION_LOCAL}" = 'YES' ]
   then
      if [ -f "${donefile}" ]
      then
         log_info "Donefile (${donefile#"${MULLE_USER_PWD}/"})"
         rexekutor cat "${donefile}"
         have_output='YES'
      else
         log_info "There is no donefile yet (${donefile#"${MULLE_USER_PWD}/"})"
      fi
   fi

   if [ "${OPTION_SHARED}" = 'YES' ]
   then

      if [ -f "${shared_donefile}" ]
      then
         if [ "${have_output}" = 'YES' ]
         then
            echo
         fi

         log_info "Shared donefile ({shared_donefile#"${MULLE_USER_PWD}/"})"
         rexekutor cat "${shared_donefile}"
      else
         log_info "There is no shared donefile (${shared_donefile#"${MULLE_USER_PWD}/"})"
      fi
   fi
}


