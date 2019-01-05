#! /usr/bin/env bash
#
#   Copyright (c) 2018 Nat! - Mulle kybernetiK
#   Copyright (c) 2018 Nat! - Codeon GmbH
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
MULLE_CRAFT_STATUS_SH="included"


status_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} status [options]

   Show the built status of the project dependencies (without subprojects).

Options:
   --output-no-color  : don't output colorized status
   -f <buildorder>    : supply buildorder file (required)

EOF
  exit 1
}


r_get_names_from_file()
{
   local donefile="$1"

   local lines

   lines="`sort "${donefile}"`"

   local line
   local names

   set -f ; IFS="
"
   for line in ${lines}
   do
      set +f ; IFS="${DEFAULT_IFS}"

      local project
      local marks

      IFS=";" read project marks <<< "${line}"

      case ",${marks}," in
         *,no-memo,*)
            # ignore subprojects
         ;;

         *)
            r_fast_basename "${project}"
            r_add_line "${names}" "${RVAL}"
            names="${RVAL}"
         ;;
      esac

   done
   set +f; IFS="${DEFAULT_IFS}"

   RVAL="${names}"
}

output_names_with_status()
{
   log_entry "output_names_with_status" "$@"

   local all_names="$1"
   local built_names="$2"

   local name
   local rval

   local ok_prefix
   local ok_suffix
   local fail_prefix
   local fail_suffix

   if [ "${OPTION_COLOR}" = 'YES' ]
   then
      ok_prefix="${C_GREEN}"
      ok_suffix="${C_RESET}"
      fail_prefix="${C_RED}"
      fail_suffix="${C_RESET}"
   else
      ok_suffix=": done"
      fail_suffix=": build"
   fi

   set -f ; IFS="
"
   for name in ${all_names}
   do
      if find_line "${built_names}" "${name}"
      then
         printf "   %b\n" "${ok_prefix}${name}${ok_suffix}"
      else
         printf "   %b\n" "${fail_prefix}${name}${fail_suffix}"
      fi
   done
   set +f; IFS="${DEFAULT_IFS}"
}


status_main()
{
   log_entry "status_main" "$@"

   local OPTION_COLOR="YES"

   while :
   do
      case "$1" in
         -h*|--help|help)
            status_usage
         ;;

         --no-memo-makeflags)
            # ignore
            shift
         ;;

         --output-no-color)
            OPTION_COLOR="NO"
         ;;

         -*)
            status_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local all_names

   if [ -z "${BUILDORDER_FILE}" ]
   then
      fail "Failed to specify buildorder with --buildorder-file <file>"
   fi

   if [ ! -f "${BUILDORDER_FILE}" ]
   then
      fail "Missing buildorder file \"${BUILDORDER_FILE}\""
   fi

   r_get_names_from_file "${BUILDORDER_FILE}"
   all_names="${RVAL}"

   local configuration
   local donefile

   for configuration in `find -H "${BUILDORDER_BUILD_DIR}" -mindepth 1 -maxdepth 1 -type d -print`
   do
      donefile="${configuration}/.mulle-craft-built"
      if [ ! -f "${donefile}" ]
      then
         continue
      fi

      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_trace2 "donefile: ${donefile}"
      fi

      r_fast_basename "${configuration}"
      configuration="${RVAL}"

      log_info "${configuration}"

      r_get_names_from_file "${donefile}"

      output_names_with_status "${all_names}" "${RVAL}"
   done
}

