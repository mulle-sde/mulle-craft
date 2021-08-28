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
MULLE_CRAFT_LOG_SH="included"


craft_log_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log [options] [project] [command]

   List available build logs and run arbitrary commands on them like
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
   <tool> ...          : use cat, egrep ack to execute on the logfiles

EOF
  exit 1
}


craft_log_list_usage()
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


project_log_dirs()
{
   log_entry "project_log_dirs" "$@"

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
      rexekutor egrep -v "^${sed_escaped_value}"
   else
      rexekutor find -H "${KITCHEN_DIR}" -type d -name .log
   fi
}


craftorder_log_dirs()
{
   log_entry "craftorder_log_dirs" "$@"

   if [ ! -d "${CRAFTORDER_KITCHEN_DIR}" ]
   then
      return 2
   fi

   rexekutor find -H "${CRAFTORDER_KITCHEN_DIR}" -type d -name .log
}


list_tool_logs()
{
   log_entry "list_tool_logs" "$@"

   local mode="$1"
   local logdir="$2"
   local project="$3"
   local configuration="$4"

   local i
   local s
   local cmdline

   cmdline="${MULLE_USAGE_NAME} log cat"

   if [ ! -z "${project}" ]
   then
      cmdline="${cmdline} -p \"${project}\""
   fi

   if [ ! -z "${configuration}" ]
   then
      cmdline="${cmdline} -c \"${configuration}\""
   fi

   log_info "${C_VERBOSE}${project}"

   shell_enable_nullglob
   for i in "${logdir}"/*.log
   do
      shell_disable_nullglob
      if [ "${mode}" = "CMD" ]
      then
         r_basename "${i}"
         i="${RVAL}"
         r_concat "${s}" "\"${i%%.log}\"" " "
         s="${RVAL}"
      else
         printf "%s\n" "${i#${MULLE_USER_PWD}/}"
      fi
   done
   shell_disable_nullglob

   if [ "${mode}" = "CMD" ]
   then
      printf "%s\n" "${cmdline} ${s}"
   fi
}


craft_log_list()
{
   log_entry "craft_log_list" "$@"

   local directory
   local configuration
   local OPTION_OUTPUT="DEFAULT"

   while :
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

   directories="`project_log_dirs`"
   log_debug "Project log-directories: ${directories}"

   if [ ! -z "${directories}" ]
   then
      log_info "Project logs"

      shell_disable_glob; IFS=$'\n'
      for directory in ${directories}
      do
         IFS="${DEFAULT_IFS}" ; shell_enable_glob

         r_dirname "${directory#${KITCHEN_DIR}/}"
         configuration="${RVAL}"

         list_tool_logs "${OPTION_OUTPUT}" "${directory}" "" "${configuration}"
      done
      IFS="${DEFAULT_IFS}" ; shell_enable_glob
   fi

   directories="`craftorder_log_dirs`"
   log_debug "Craftorder log-directories: ${directories}"

   if [ ! -z "${directories}" ]
   then
      log_info "Craftorder logs"

      local configuration_name
      local name

      shell_disable_glob; IFS=$'\n'
      for directory in ${directories}
      do
         IFS="${DEFAULT_IFS}" ; shell_enable_glob

         r_dirname "${directory#${CRAFTORDER_KITCHEN_DIR}/}"
         configuration_name="${RVAL}"
         configuration="${configuration_name%%/*}"
         name="${configuration_name#*/}"
         list_tool_logs "${OPTION_OUTPUT}" "${directory}" "${name}" "${configuration}"
      done
      IFS="${DEFAULT_IFS}" ; shell_enable_glob
   fi
}


craft_log_command()
{
   log_entry "craft_log_command" "$@"

   local name="$1"; shift

   while :
   do
      case "$1" in
         -h*|--help|help)
            craft_log_usage
         ;;

         -*)
            craft_log_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local cmd="${1:-cat}"
   [ $# -ne 0 ] && shift

   local directory
   local logfiles
   local logfile

   local sdk="${OPTION_SDK}"
   local platform="${OPTION_PLATFORM}"
   local configuration="${OPTION_CONFIGURATION}"
   local style="${MULLE_CRAFT_DISPENSE_STYLE:-none}"

   local lastsdk
   local lastplatform
   local lastconfiguration

   if [ ! -z "${name}" ]
   then
      #
      # try to figure out what the last run used for sdk/platform/config
      # use these values as default, if none are specified
      #
      local lastvalues

      lastvalues="`rexekutor egrep -s -v '^#' "${CRAFTORDER_KITCHEN_DIR}/.mulle-craft-last"`"

      lastsdk="${lastvalues%%;*}"
      lastplatform="${lastvalues%;*}"
      lastplatform="${lastplatform#*;}"
      lastconfiguration="${lastvalues##*;}"

      log_debug "lastvalues: ${lastsdk};${lastplatform};${lastconfiguration}"
   fi

   sdk="${sdk:-${lastsdk}}"
   platform="${platform:-${lastplatform}}"
   configuration="${configuration:-${lastconfiguration}}"

   sdk="${sdk:-Default}"
   platform="${platform:-${MULLE_UNAME}}"
   configuration="${configuration:-Release}"

   if [ ! -z "${name}" ]
   then
      [ -z "${MULLE_CRAFT_STYLE_SH}" ] && \
            . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-style.sh"


      local _kitchendir
      local _configuration
      local _evaledproject
      local _name

      _evaluate_craft_variables "${name}" \
                                "${sdk}" \
                                "${platform}" \
                                "${configuration}" \
                                "${style}" \
                                "${CRAFTORDER_KITCHEN_DIR#${PWD}/}" \
                                "NO"

      directory="${_kitchendir}"

      log_debug "Build directory: ${directory}"

      # build/.craftorder/Debug/mulle-c11/.log/
      local prefix
      local found
      local globpattern

      globpattern="${directory}/.log/${OPTION_TOOL}.log"
#      echo ${globpattern}

      # just ensure globbing is ON!
      shell_enable_nullglob
#      echo ""
      for i in ${globpattern}
      do
         shell_disable_nullglob

         log_info "${C_RESET_BOLD}${i}:"
         exekutor "${cmd}" "$@" "${i}"
         found="YES"
      done
      shell_disable_nullglob

      if [ -z "${found}" ]
      then
         log_verbose "No craftorder logs match for \"${name}\" (${globpattern})"
      fi
   fi

   #
   # Show logs of main if only main or all are selected
   #
   case "${name}" in
      ''|'*')
         log_info "${PROJECT_NAME}"

         directory="${KITCHEN_DIR#${PWD}/}"
         log_debug "Project build directory: ${directory}"

         # https://stackoverflow.com/questions/2937407/test-whether-a-glob-matches-any-files#
         logfiles=
         if rexekutor compgen -G "${directory}" > /dev/null 2>&1
         then
            logfiles="${directory}/${configuration}/.log/${OPTION_TOOL}.log"
         fi

         if [ ! -z "${logfiles}" ]
         then
            shell_enable_nullglob
            for i in ${logfiles}
            do
               shell_disable_nullglob
               log_info "${C_RESET_BOLD}${i}:"
               exekutor "${cmd}" "$@" "${i}"
            done
            shell_disable_nullglob
         else
            log_verbose "No project logs match"
         fi
      ;;
   esac
}



#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
craft_log_main()
{
   log_entry "craft_log_main" "$@"

   local OPTION_CONFIGURATION="*"
   local OPTION_TOOL="*"
   local OPTION_EXECUTABLE=""

   while :
   do
      case "$1" in
         -h*|--help|help)
            craft_log_usage
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

         -t|--tool)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_TOOL="$1"
         ;;

         -*)
            craft_log_usage "Unknown option \"$1\""
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
         craft_log_list "$@"
      ;;

      *)
         craft_log_command "$@"
      ;;
   esac
}

