# shellcheck shell=bash
# shellcheck disable=SC2236
# shellcheck disable=SC2166
# shellcheck disable=SC2006
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
MULLE_CRAFT_STATUS_SH='included'


craft::status::usage()
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


craft::status::r_get_names_from_file()
{
   local donefile="$1"

   local lines

   lines="`rexekutor sort "${donefile}"`"

   local line
   local names
   local project
   local marks

   .foreachline line in ${lines}
   .do
      IFS=";" read project marks <<< "${line}"

      case ",${marks}," in
         *,no-mainproject,*)
            # ignore subprojects
         ;;

         *)
            r_basename "${project}"
            # Store name with marks: name;marks
            r_add_line "${names}" "${RVAL};${marks}"
            names="${RVAL}"
         ;;
      esac
   .done

   RVAL="${names}"
}


craft::status::output_names_with_status()
{
   log_entry "craft::status::output_names_with_status" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   shift 3

   local all_names="$1"
   local built_names="$2"
   local kitchendir="$3"
   local is_main="${4:-NO}"
   local mode="$5"

   local name
   local rc

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
   local _toolchain
   
   local phase
   local project
   local state

   local terse

   case ",${mode}," in
      *,terse,*)
         terse='YES'
      ;;
   esac

   include "craft::path"

   local actual_name
   local marks
   local in_donefile
   local has_kitchen
   local has_dependency
   local age_info
   local is_craftinfo
   local skip_platform
   local dep_path
   local dep_mtime
   local now_time
   local age_seconds
   local missing

   .foreachline name in ${all_names}
   .do
      # Extract name and marks
      IFS=";" read actual_name marks <<< "${name}"

      #
      # get remapped _configuration
      # get actual _kitchendir
      #


      if [ "${is_main}" = 'YES' ]
      then
         craft::path::r_mainproject_kitchendir "${sdk}" \
                                               "${platform}" \
                                               "${configuration}" \
                                               "relax" \
                                               "${kitchendir}"
         _kitchendir="${RVAL}"
         _configuration="${configuration}"
      else
         craft::path::__evaluate_variables "${actual_name}" \
                                           "${sdk}" \
                                           "${platform}" \
                                           "${configuration}" \
                                           "relax" \
                                           "${kitchendir}" \
                                           'NO'
      fi

      phase="`grep -E -v '^#' "${_kitchendir}/.phase" 2> /dev/null`"
      project="`grep -E -v '^#' "${_kitchendir}/.project" 2> /dev/null`"
      rc="`grep -E -v '^#' "${_kitchendir}/.status" 2> /dev/null`"

      log_setting "_kitchendir    : ${_kitchendir}"
      log_setting "_configuration : ${_configuration}"
      log_setting "phase          : ${phase}"
      log_setting "project        : ${project}"
      log_setting "rc           : ${rc}"
      log_setting "marks          : ${marks}"

      # make it so it lists completed phases, which is less confusing IMO
      if [ ! -z "${phase}" ]
      then
         case "${phase}" in
            'Header'|'Headers')
               if [ $rc -eq 0 ]
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

      in_donefile='NO'
      has_kitchen='NO'
      has_dependency='NO'
      age_info=""
      is_craftinfo='NO'
      skip_platform='NO'

      # Check if this dependency should be skipped for this platform
      case ",${marks}," in
         *,no-craft-platform-${platform},*)
            skip_platform='YES'
         ;;
      esac

      # Check if this is craftinfo-only (no actual build artifacts)
      # Must have both no-header and no-link
      case ",${marks}," in
         *,no-header,*)
            case ",${marks}," in
               *,no-link,*)
                  is_craftinfo='YES'
               ;;
            esac
         ;;
      esac

      # Check if in donefile (need to search for name with marks)
      if find_line "${built_names}" "${name}"
      then
         in_donefile='YES'
      fi

      if [ -d "${_kitchendir}" ]
      then
         has_kitchen='YES'
      fi

      # Check if dependency exists in dependency dir (configuration-specific)
      # Try multiple locations:
      # 1. include/${name}/ subdirectory
      # 2. lib/lib${name}.a library file (if name doesn't start with "lib")
      # 3. lib/${name}.a library file (if name starts with "lib")
      dep_path="${DEPENDENCY_DIR}/${_configuration}/include/${actual_name}"
      if [ -d "${dep_path}" ]
      then
         has_dependency='YES'
      else
         # Check for library file
         case "${actual_name}" in
            lib*)
               # Name already starts with lib, don't add another
               dep_path="${DEPENDENCY_DIR}/${_configuration}/lib/${actual_name}.a"
            ;;
            *)
               dep_path="${DEPENDENCY_DIR}/${_configuration}/lib/lib${actual_name}.a"
            ;;
         esac
         if [ -f "${dep_path}" ]
         then
            has_dependency='YES'
         fi
      fi

      # Calculate age from dependency dir if found
      if [ "${has_dependency}" = 'YES' -a "${OPTION_COLOR}" = 'YES' ]
      then
         dep_mtime="$(stat -c %Y "${dep_path}" 2>/dev/null || stat -f %m "${dep_path}" 2>/dev/null)"
         if [ ! -z "${dep_mtime}" ]
         then
            now_time="$(date +%s)"
            age_seconds=$((now_time - dep_mtime))

            # Format age
            if [ ${age_seconds} -lt 60 ]
            then
               age_info="${age_seconds}s ago"
            elif [ ${age_seconds} -lt 3600 ]
            then
               age_info="$((age_seconds / 60))m ago"
            elif [ ${age_seconds} -lt 86400 ]
            then
               age_info="$((age_seconds / 3600))h ago"
            else
               age_info="$((age_seconds / 86400))d ago"
            fi
         fi
      fi

      # Determine overall status
      # Skip dependencies that shouldn't be built for this platform
      if [ "${skip_platform}" = 'YES' ]
      then
         printf "   %b" "${ok_prefix}${actual_name}${ok_suffix}"
         state="OK  (skipped for ${platform})"
         rc=""
      # For craftinfo-only, we only need it to be in donefile (crafted)
      elif [ "${is_craftinfo}" = 'YES' ]
      then
         if [ "${in_donefile}" = 'YES' ]
         then
            printf "   %b" "${ok_prefix}${actual_name}${ok_suffix}"
            state="OK"
            rc=""
         else
            printf "   %b" "${fail_prefix}${actual_name}${fail_suffix}"
            state="-  missing: crafted"
            rc=""
         fi
      elif [ "${in_donefile}" = 'YES' -a "${has_kitchen}" = 'YES' -a "${has_dependency}" = 'YES' ]
      then
         printf "   %b" "${ok_prefix}${actual_name}${ok_suffix}"
         case "${rc}" in
            0)
               state="OK"
               if [ ! -z "${age_info}" ]
               then
                  state="OK  ${age_info}"
               fi
               rc=""
            ;;

            *)
               state="???"
            ;;
         esac
      else
         printf "   %b" "${fail_prefix}${actual_name}${fail_suffix}"
         state="-"

         # Build missing list (renamed: kitchen→started, done→crafted, dependency→installed)
         missing=""
         if [ "${has_kitchen}" = 'NO' ]
         then
            missing="started"
         fi
         if [ "${in_donefile}" = 'NO' ]
         then
            if [ ! -z "${missing}" ]
            then
               missing="${missing}, crafted"
            else
               missing="crafted"
            fi
         fi
         if [ "${has_dependency}" = 'NO' ]
         then
            if [ ! -z "${missing}" ]
            then
               missing="${missing}, installed"
            else
               missing="installed"
            fi
         fi

         if [ ! -z "${missing}" ]
         then
            state="-  missing: ${missing}"
         fi
         rc=""
      fi

      if [ "${terse}" = 'YES' ]
      then
         printf ";%s;%s;%s\n" "${state}" "${phase:-Singlephase}" "${rc}"
      else
         printf ";%s\n" "${state}"
      fi
   .done
}


craft::status::output()
{
   log_entry "craft::status::output" "$@"

   craft::status::output_names_with_status "$@" | rexecute_column_table_or_cat ';'
}


#   local _configuration
#   local _sdk
#   local _platform
craft::status::__parse_triple()
{
   log_entry "craft::status::__parse_triple" "$@"

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
      log_setting "sdk:           ${_sdk}"
      log_setting "platform:      ${_platform}"
      log_setting "configuration: ${_configuration}"
   fi
}


#   local _configuration
#   local _sdk
#   local _platform
craft::status::__parse_donefile()
{
   log_entry "craft::status::__parse_donefile" "$@"

   local donefile="$1"

   r_extensionless_basename "${donefile}"
   name="${RVAL}"

   craft::status::__parse_triple "${name}"
}


craft::status::output_with_donefile()
{
   log_entry "craft::status::output_with_donefile" "$@"

   local donefile="$1"
   local kitchendir="$2"
   local mode="$3"

   local _configuration
   local _sdk
   local _platform

   craft::status::__parse_donefile "${donefile}"

   _log_info " SDK:${C_MAGENTA}${C_BOLD}${_sdk}${C_INFO} \
Platform:${C_MAGENTA}${C_BOLD}${_platform}${C_INFO} \
Configuration:${C_MAGENTA}${C_BOLD}${_configuration}${C_INFO}"

   local done_names

   craft::status::r_get_names_from_file "${donefile}"
   done_names="${RVAL}"

   craft::status::output "${_sdk}" "${_platform}" "${_configuration}" \
                       "${all_names}" "${done_names}" "${kitchendir}" \
                       "NO" \
                       "${mode}"
}


craft::status::main()
{
   log_entry "craft::status::main" "$@"

   local OPTION_COLOR='YES'
   local mode

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft::status::usage
         ;;

         --no-memo-makeflags)
            # ignore
            shift
         ;;

         --output-no-color)
            OPTION_COLOR='NO'
         ;;

         --output-terse)
            r_comma_concat "${mode}" "terse"
            mode="${RVAL}"
         ;;

         -*)
            craft::status::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   [ -z "${CRAFTORDER_KITCHEN_DIR}" ] \
   && _internal_fail "CRAFTORDER_KITCHEN_DIR is empty"

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

   craft::status::r_get_names_from_file "${CRAFTORDER_FILE}"
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
      log_info "Craft status of ${C_RESET_BOLD}${ADDICTION_DIR#"${MULLE_USER_PWD}/"}"

      # we can only figure out if the state is complete
      state="`grep -E -v '^#' "${ADDICTION_DIR}/.state" `"

      case "${state}" in
         complete)
            printf "   ${C_GREEN}%s${C_RESET}   OK\n" "${ADDICTION_DIR#"${MULLE_USER_PWD}/"}"
         ;;

         *)
            printf "   ${C_RED}%s${C_RESET}   FAIL\n" "${ADDICTION_DIR#"${MULLE_USER_PWD}/"}"
         ;;
      esac
   fi

   if [ ! -z "${dependency_donefiles}" ]
   then
      log_info "Craft status of ${C_RESET_BOLD}${DEPENDENCY_DIR#"${MULLE_USER_PWD}/"}"
      .for donefile in ${dependency_donefiles}
      .do
         craft::status::output_with_donefile "${donefile}" \
                                             "${CRAFTORDER_KITCHEN_DIR}"
      .done
   fi

   if [ -f "${KITCHEN_DIR}/.mulle-craft-last" ]
   then
      log_info "Craft status of ${C_RESET_BOLD}${PROJECT_NAME}"

      local triple

      triple="`grep -E -v '^#' "${KITCHEN_DIR}/.mulle-craft-last" `"

      local _configuration
      local _sdk
      local _platform

      craft::status::__parse_triple "${triple//;/--}"

      craft::status::output "${_sdk}" \
                            "${_platform}" \
                            "${_configuration}" \
                            "${PROJECT_NAME}" \
                            "${PROJECT_NAME}" \
                            "${KITCHEN_DIR}" \
                            "YES" \
                            "${mode}"
   fi
}

