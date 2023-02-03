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
MULLE_CRAFT_LOG_SH='included'


craft::log::usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log [options] [command] [project]

   List available build logs or run arbitrary commands on them like
   'cat' or 'grep', where 'cat' is the default.

   Show last project logs with:

      ${MULLE_USAGE_NAME} log

   Grep for 'error:' through all project logs with:

      ${MULLE_USAGE_NAME} log '*' grep 'error:'

Options:
   -c <configuration>  : restrict to configuration
   -t <tool>           : restrict to tool

Project:
   *                   : all projects
   ""                  : main project
   <name>              : name of project

Commands:
   list                : list available build logs
   <tool> ...          : use cat, grep -E ack to execute on the logfiles

EOF
  exit 1
}


craft::log::list_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log [options] list

   List available build logs.

Options:
   --output-format cmd  : list as ${MULLE_USAGE_NAME} log commands (default)
   --output-filename    : list as files

EOF
  exit 1
}


craft::log::project_log_dirs()
{
   log_entry "craft::log::project_log_dirs" "$@"

   if [ ! -d "${KITCHEN_DIR}" ]
   then
      return 4
   fi

   if [ ! -z "${CRAFTORDER_KITCHEN_DIR}" ]
   then
      local sed_escaped_value

      r_escaped_sed_pattern "${CRAFTORDER_KITCHEN_DIR}"
      sed_escaped_value="${RVAL}"
      rexekutor find -H "${KITCHEN_DIR}" -type d -name .log | \
      rexekutor grep -E -v "^${sed_escaped_value}"
   else
      rexekutor find -H "${KITCHEN_DIR}" -type d -name .log
   fi
}


craft::log::craftorder_log_dirs()
{
   log_entry "craft::log::craftorder_log_dirs" "$@"

   if [ ! -d "${CRAFTORDER_KITCHEN_DIR}" ]
   then
      return 2
   fi

   rexekutor find -H "${CRAFTORDER_KITCHEN_DIR}" -type d -name .log
}


craft::log::list_tool_logs()
{
   log_entry "craft::log::list_tool_logs" "$@"

   local mode="$1"
   local logdir="$2"
   local project="$3"
   local configuration="$4"

   [ ! -d  "${logdir}" ] && return

   local i
   local s
   local cmdline

   cmdline="${MULLE_USAGE_NAME} log cat"

   if [ ! -z "${project}" ]
   then
      log_info "${C_VERBOSE}${project}"

      cmdline="${cmdline} -p \"${project}\""
   fi

   if [ ! -z "${configuration}" ]
   then
      cmdline="${cmdline} -c \"${configuration}\""
   fi

   .foreachline i in `dir_list_files "${logdir}" "*.log" "f"`
   .do
      if [ "${mode}" = "CMD" ]
      then
         r_basename "${i}"
         i="${RVAL}"
         r_concat "${s}" "\"${i%%.log}\"" " "
         s="${RVAL}"
      else
         printf "%s\n" "${i#"${MULLE_USER_PWD}/"}"
      fi
   .done

   if [ "${mode}" = "CMD" ]
   then
      printf "%s\n" "${cmdline} ${s}"
   fi
}


craft::log::list()
{
   log_entry "craft::log::list" "$@"

   local directory
   local configuration
   local OPTION_OUTPUT="DEFAULT"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft_log_cat_usage
         ;;

         --output-format)
            shift
            OPTION_OUTPUT="CMD"
         ;;

         --output-filename)
            OPTION_OUTPUT="FILENAME"
         ;;

         -c|--configuration)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         -*)
            craft_log_cat_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   directories="`craft::log::project_log_dirs`"
   log_debug "Project log-directories: ${directories}"

   if [ ! -z "${directories}" ]
   then
      log_info "Project logs"

      .foreachline directory in ${directories}
      .do
         r_dirname "${directory#${KITCHEN_DIR}/}"
         configuration="${RVAL}"

         craft::log::list_tool_logs "${OPTION_OUTPUT}" "${directory}" "" "${configuration}"
      .done
   fi

   directories="`craft::log::craftorder_log_dirs`" || exit 1

   log_debug "Craftorder log-directories: ${directories}"

   if [ ! -z "${directories}" ]
   then
      log_info "Craftorder logs"

      local configuration_name
      local name

      .foreachline directory in ${directories}
      .do
         r_dirname "${directory#${CRAFTORDER_KITCHEN_DIR}/}"
         configuration_name="${RVAL}"
         configuration="${configuration_name%%/*}"
         name="${configuration_name#*/}"

         craft::log::list_tool_logs "${OPTION_OUTPUT}" "${directory}" "${name}" "${configuration}"
      .done
   fi
}


craft::log::craftorders()
{
   log_entry "craft::log::craftorders" "$@"

   local name="$1"
   local cmd="$2"

   shift 2

   local lastvalues

   if [ -f "${CRAFTORDER_KITCHEN_DIR}/.mulle-craft-last" ]
   then
      lastvalues="`rexekutor grep -E -v '^#' "${CRAFTORDER_KITCHEN_DIR}/.mulle-craft-last"`"
   fi

   local lastsdk
   local lastplatform
   local lastconfiguration

   lastsdk="${lastvalues%%;*}"
   lastplatform="${lastvalues%;*}"
   lastplatform="${lastplatform#*;}"
   lastconfiguration="${lastvalues##*;}"

   log_debug "lastvalues: ${lastsdk};${lastplatform};${lastconfiguration}"

   local sdk="${OPTION_SDK}"
   local platform="${OPTION_PLATFORM}"
   local style="${OPTION_SDK:-${MULLE_CRAFT_DISPENSE_STYLE:-auto}}"

   configuration="${OPTION_CONFIGURATION}"
   configuration="${configuration:-${lastconfiguration}}"
   configuration="${configuration:-Release}"

   sdk="${sdk:-${lastsdk}}"
   platform="${platform:-${lastplatform}}"

   sdk="${sdk:-Default}"
   platform="${platform:-${MULLE_UNAME}}"

   include "craft::style"

   log_setting "sdk           : ${sdk}"
   log_setting "platform      : ${platform}"
   log_setting "configuration : ${configuration}"

   local _kitchendir
   local _configuration
   local _evaledproject
   local _name

   include "craft::path"

   craft::path::__evaluate_variables "${name}" \
                                     "${sdk}" \
                                     "${platform}" \
                                     "${configuration}" \
                                     "${style}" \
                                      "${CRAFTORDER_KITCHEN_DIR#${PWD}/}" \
                                    'NO'

   log_debug "Build directory: ${_kitchendir}"

   # build/.craftorder/Debug/mulle-c11/.log/
   local globpattern

   r_filepath_concat "${_kitchendir}" ".log" "*.${OPTION_TOOL:-*}.log"
   globpattern="${RVAL}"

   log_debug "globpattern: ${globpattern}"

   local found
   local i

   .foreachfile i in ${globpattern}
   .do
      if [ -e "${i}" ] # stupid zsh, need to figure it out
      then
         log_info "${C_RESET_BOLD}${i}:"
         exekutor "${cmd}" "$@" "${i}"
         found='YES'
      fi
   .done

   if [ -z "${found}" ]
   then
      log_verbose "No craftorder logs match for \"${name}\" (${globpattern})"
   fi
}


craft::log::directories_list_files()
{
   local directories

   while :
   do
      case "$1" in
         --)
            shift
            break
         ;;

         *)
            r_add_line "${directories}" "$1"
            directories="${RVAL}"
      esac

      shift
   done

   .foreachline directory in ${directories}
   .do
      dir_list_files "${directory}" "$@"
   .done
}



craft::log::project()
{
   log_entry "craft::log::project" "$@"

   local cmd="$1"

   [ $# -ne 0 ] && shift

   log_info "${PROJECT_NAME:-${PWD}}"

   local configuration

   configuration="${OPTION_CONFIGURATION}"
   configuration="${configuration:-Release}"

   local logfiles
   local directory

   directory="${KITCHEN_DIR#${PWD}/}"

   shell_enable_nullglob
   shell_enable_glob

   log_debug "Log pattern : ${directory}/${configuration}/.log/*.${OPTION_TOOL:-*}.log"
   logfiles="`craft::log::directories_list_files "${directory}"/${configuration}/".log/" -- "*.${OPTION_TOOL:-*}.log" `"
   shell_disable_nullglob

   log_debug "Log files   : ${logfiles}"

   local i

   if [ ! -z "${logfiles}" ]
   then
      .foreachline i in ${logfiles}
      .do
         log_info "${C_RESET_BOLD}${i}:"
         exekutor "${cmd}" "$@" "${i}"
      .done
   else
      log_verbose "No project logs match"
   fi
}



craft::log::command()
{
   log_entry "craft::log::command" "$@"

   local name="$1"
   [ $# -ne 0 ] && shift

   local cmd="${1:-cat}"
   [ $# -ne 0 ] && shift

   if [ ! -z "${name}" ]
   then
      #
      # try to figure out what the last run used for sdk/platform/config
      # use these values as default, if none are specified
      #
      craft::log::craftorders "${name}" "${cmd}" "$@"
   fi


   #
   # Show logs of main if only main or all are selected
   #
   case "${name}" in
      ''|'*')
         craft::log::project "${cmd}" "$@"
      ;;
   esac
}


#
# mulle-craft isn't ruled so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
craft::log::main()
{
   log_entry "craft::log::main" "$@"

   local OPTION_CONFIGURATION="*"
   local OPTION_TOOL="*"
   local OPTION_EXECUTABLE=""

   while :
   do
      case "$1" in
         -h*|--help|help)
            craft::log::usage
         ;;

         -e|--executable)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_EXECUTABLE="$1"
         ;;

         -c|--configuration)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         -p|--platform)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         -s|--sdk)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         --style)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_STYLE="$1"
         ;;

         -t|--tool)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_TOOL="$1"
         ;;

         -*)
            craft::log::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   if [ -z "${KITCHEN_DIR}" ]
   then
      fail "Unknown kitchen directory, specify with -k"
   fi

   case "$1" in
      list)
         shift
         craft::log::list "$@"
      ;;

      *)
         craft::log::command "$@"
      ;;
   esac
}

