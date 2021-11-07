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

   Show the craft status of the project dependencies (without subprojects).

   Use mulle-sde craftorder --print-craftorder-file to get the necessary craftorder file.

Options:
   --output-no-color  : don't output colorized status
   -f <craftorder>    : supply craftorder file (required)

EOF
  exit 1
}


r_get_names_from_file()
{
   local donefile="$1"

   local lines

   lines="`rexekutor sort "${donefile}"`"

   local line
   local names

   shell_disable_glob; IFS=$'\n'
   for line in ${lines}
   do
      shell_enable_glob; IFS="${DEFAULT_IFS}"

      local project
      local marks

      IFS=";" read project marks <<< "${line}"

      case ",${marks}," in
         *,no-mainproject,*)
            # ignore subprojects
         ;;

         *)
            r_basename "${project}"
            r_add_line "${names}" "${RVAL}"
            names="${RVAL}"
         ;;
      esac

   done
   shell_enable_glob; IFS="${DEFAULT_IFS}"

   RVAL="${names}"
}


output_names_with_status()
{
   log_entry "output_names_with_status" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   shift 3
   local all_names="$1"
   local built_names="$2"
   local kitchendir="$3"
   local is_main="${4:-NO}"

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

   ##
   ## get build directoy and retrieve some info
   ##
   local _name
   local _evaledproject
   local _kitchendir
   local _configuration

   local phase
   local project
   local state
   local rval

   local terse

   case ",${mode}," in
      *,terse,*)
         terse='YES'
      ;;
   esac

   shell_disable_glob; IFS=$'\n'
   for name in ${all_names}
   do
      #
      # get remapped _configuration
      # get actual _kitchendir
      #

      if [ -z "${MULLE_CRAFT_STYLE_SH}" ]
      then
         . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-style.sh"
      fi

      if [ "${is_main}" = "YES" ]
      then
         r_craft_mainproject_kitchendir "${sdk}" \
                                        "${platform}" \
                                        "${configuration}" \
                                        "${kitchendir}"
         _kitchendir="${RVAL}"
         _configuration="${configuration}"
      else
         _evaluate_craft_variables "${name}" \
                                   "${sdk}" \
                                   "${platform}" \
                                   "${configuration}" \
                                   "relax" \
                                   "${kitchendir}" \
                                   "NO"
      fi

      phase="`egrep -v '^#' "${_kitchendir}/.phase" 2> /dev/null`"
      project="`egrep -v '^#' "${_kitchendir}/.project" 2> /dev/null`"
      rval="`egrep -v '^#' "${_kitchendir}/.status" 2> /dev/null`"

      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_trace2 "_kitchendir    : ${_kitchendir}"
         log_trace2 "_configuration : ${_configuration}"
         log_trace2 "phase          : ${phase}"
         log_trace2 "project        : ${project}"
         log_trace2 "rval           : ${rval}"
      fi

      # make it so it lists completed phases, which is less confusing IMO
      if [ ! -z "${phase}" ]
      then
         case "${phase}" in
            'Header'|'Headers')
               if [ $rval -eq 0 ]
               then
                  phase="Multiphase (Header)"
               else
                  phase="Multiphase ()"
               fi
            ;;

            Compile)
               phase="Multiphase (Header, Compile)"
            ;;

            Link)
               phase="Multiphase (Header, Compile, Link)"
            ;;
         esac
      fi

      if find_line "${built_names}" "${name}"
      then
         printf "   %b" "${ok_prefix}${name}${ok_suffix}"
         case "${rval}" in
            0)
               state="OK"
               rval=""
            ;;

            *)
               state="???"
            ;;
         esac
      else
         printf "   %b" "${fail_prefix}${name}${fail_suffix}"
         if [ -z "${project}" ]
         then
            state="-"
            rval=""
         else
            state="FAIL"
         fi
      fi

      if [ "${terse}" = 'YES' ]
      then
         printf ";%s;%s;%s\n" "${state}" "${phase:-Singlephase}" "${rval}"
      else
         printf ";%s\n" "${state}"
      fi
   done
   shell_enable_glob; IFS="${DEFAULT_IFS}"
}


craft_status_output()
{
   log_entry "craft_status_output" "$@"

   output_names_with_status "$@" | rexecute_column_table_or_cat ';'
}


#   local _configuration
#   local _sdk
#   local _platform
__craft_status_parse_triple()
{
   log_entry "__craft_status_parse_triple" "$@"

   local name="$1"


   # format sdk-platform-configuration

   local s

   s="${name#craftorder-}"
   _sdk="${s%%--*}"
   s="${s#${_sdk}}"
   s="${s#--}"
   _platform="${s%%--*}"
   s="${s#${_platform}--}"
   _configuration="$s"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "sdk:           ${_sdk}"
      log_trace2 "platform:      ${_platform}"
      log_trace2 "configuration: ${_configuration}"
   fi
}


#   local _configuration
#   local _sdk
#   local _platform
__craft_status_parse_donefile()
{
   log_entry "__craft_status_parse_donefile" "$@"

   local donefile="$1"

   r_extensionless_basename "${donefile}"
   name="${RVAL}"

   __craft_status_parse_triple "${name}"
}



status_output_with_donefile()
{
   log_entry "status_output_with_donefile" "$@"

   local donefile="$1"
   local kitchendir="$2"
   local mode="$3"

   local _configuration
   local _sdk
   local _platform

   __craft_status_parse_donefile "${donefile}"

   log_info " SDK:${C_MAGENTA}${C_BOLD}${_sdk}${C_INFO} \
Platform:${C_MAGENTA}${C_BOLD}${_platform}${C_INFO} \
Configuration:${C_MAGENTA}${C_BOLD}${_configuration}${C_INFO}"

   local done_names

   r_get_names_from_file "${donefile}"
   done_names="${RVAL}"

   craft_status_output "${_sdk}" "${_platform}" "${_configuration}" \
                       "${all_names}" "${done_names}" "${kitchendir}" \
                       "${mode}"
}


status_main()
{
   log_entry "status_main" "$@"

   local OPTION_COLOR="YES"
   local mode

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

         --output-terse)
            r_comma_concat "${mode}" "terse"
            mode="${RVAL}"
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

   [ -z "${CRAFTORDER_KITCHEN_DIR}" ] \
   && internal_fail "CRAFTORDER_KITCHEN_DIR is empty"

   if [ -z "${CRAFTORDER_FILE}" ]
   then
      fail "You must specify the craftorder with --craftorder-file <file>"
   fi

   if [ "${CRAFTORDER_FILE}" = "NONE" ]
   then
      log_verbose "Nothing to show as no craftorder file was given"
      return 0
   fi

   if [ ! -f "${CRAFTORDER_FILE}" ]
   then
      fail "Missing craftorder file \"${CRAFTORDER_FILE}\""
   fi

   local all_names

   r_get_names_from_file "${CRAFTORDER_FILE}"
   all_names="${RVAL}"

   log_debug "names: ${all_names}"

   if [ ! -d "${CRAFTORDER_KITCHEN_DIR}" ]
   then
      log_info "Nothing crafted yet"
      return 0
   fi

   local addiction_donefiles
   local dependency_donefiles

   # retarded bash shell can't nullglob variables
   addiction_donefiles="$( echo "${ADDICTION_DIR}/etc/craftorder"-*--*--* )"
   dependency_donefiles="$( echo "${DEPENDENCY_DIR}/etc/craftorder"-*--*--* )"

   if [ "${addiction_donefiles}" = "${ADDICTION_DIR}/etc/craftorder-*--*--*" ]
   then
      addiction_donefiles=
   fi
   if [ "${dependency_donefiles}" = "${DEPENDENCY_DIR}/etc/craftorder-*--*--*" ]
   then
      dependency_donefiles=
   fi

   if [ ! -f "${KITCHEN_DIR}/.mulle-craft" ]
   then
      if [ -z "${dependency_donefiles}" -a -z "${addiction_donefiles}" ]
      then
         log_info "Not dependencies have been built yet"
         return 0
      fi
   fi

   local donefile

   if [ ! -z "${addiction_donefiles}" ]
   then
      log_info "Craft status of ${C_RESET_BOLD}${ADDICTION_DIR#${MULLE_USER_PWD}/}"

      # we can only figure out if the state is complete
      state="`egrep -v '^#' "${ADDICTION_DIR}/.state" `"

      case "${state}" in
         complete)
            printf "   ${C_GREEN}%s${C_RESET}   OK\n" "${ADDICTION_DIR#${MULLE_USER_PWD}/}"
         ;;

         *)
            printf "   ${C_RED}%s${C_RESET}   FAIL\n" "${ADDICTION_DIR#${MULLE_USER_PWD}/}"
         ;;
      esac
   fi

   if [ ! -z "${dependency_donefiles}" ]
   then
      log_info "Craft status of ${C_RESET_BOLD}${DEPENDENCY_DIR#${MULLE_USER_PWD}/}"
      for donefile in ${dependency_donefiles}
      do
         status_output_with_donefile "${donefile}" \
                                     "${CRAFTORDER_KITCHEN_DIR}"
      done
   fi

   if [ -f "${KITCHEN_DIR}/.mulle-craft-last" ]
   then
      log_info "Craft status of ${C_RESET_BOLD}${PROJECT_NAME}"

      local triple

      triple="`egrep -v '^#' "${KITCHEN_DIR}/.mulle-craft-last" `"

      local _configuration
      local _sdk
      local _platform

      __craft_status_parse_triple "${triple//;/--}"

      craft_status_output "${_sdk}" "${_platform}" "${_configuration}" \
                          "${PROJECT_NAME}" "${PROJECT_NAME}" \
                          "${KITCHEN_DIR}" "${mode}" \

   fi
}

