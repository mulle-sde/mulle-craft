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


build_log_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log [options] <command>

   List available build logs and run arbitrary commands on them like
   'cat' or 'grep'

   Show last project logs with:

      ${MULLE_USAGE_NAME} log cat

   Dump all project logs with:

      ${MULLE_USAGE_NAME} log -p '*' cat

Options:
   -c <configuration>  : restrict to configuration
   -p <project>        : project, leave empty for main project
   -t <tool>           : restrict to tool

Commands:
   list                : list available build logs
   <tool> ...          : use cat, egrep ack to execute on the logfiles

EOF
  exit 1
}


build_log_list_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log [options] list

   List available build logs.

Options:
   --output-cmd      : list as ${MULLE_USAGE_NAME} log commands (default)
   --output-filename : list as files

EOF
  exit 1
}


project_log_dirs()
{
   log_entry "project_log_dirs" "$@"

   if [ ! -d "${BUILD_DIR}" ]
   then
      return 2
   fi

   if [ ! -z "${BUILDORDER_BUILD_DIR}" ]
   then
      local sed_escaped_value

      sed_escaped_value="`escaped_sed_pattern "${BUILDORDER_BUILD_DIR}"`"
      rexekutor find "${BUILD_DIR}" -type d -name .log | rexekutor egrep -v "^${sed_escaped_value}"
   else
      rexekutor find "${BUILD_DIR}" -type d -name .log
   fi
}


buildorder_log_dirs()
{
   log_entry "buildorder_log_dirs" "$@"

   if [ ! -d "${BUILDORDER_BUILD_DIR}" ]
   then
      return 2
   fi

   rexekutor find "${BUILDORDER_BUILD_DIR}" -type d -name .log
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

   for i in "${logdir}"/*.log
   do
      if [ "${mode}" = "CMD" ]
      then
         i="`fast_basename "${i}"`"
         s="`concat "${s}" "\"${i%%.log}\"" " "`"
      else
         echo "${i#${MULLE_USER_PWD}/}"
      fi
   done


   if [ "${mode}" = "CMD" ]
   then
      echo "${cmdline} ${s}"
   fi
}


build_log_list()
{
   log_entry "build_log_list" "$@"

   local directory
   local configuration
   local OPTION_OUTPUT="DEFAULT"

   while :
   do
      case "$1" in
         -h*|--help|help)
            build_log_cat_usage
         ;;

         --output-cmd|--output-command)
            OPTION_OUTPUT="CMD"
         ;;

         --output-filename)
            OPTION_OUTPUT="FILENAME"
         ;;

         -p|--project|--project-name)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_NAME="$1"
         ;;

         -c|--configuration)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         -*)
            build_log_cat_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   directories="`project_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      log_info "Project logs"

      set -o noglob; IFS="
"
      for directory in ${directories}
      do
         IFS="${DEFAULT_IFS}" ; set +o noglob

         configuration="`fast_dirname "${directory#${BUILD_DIR}/}"`"

         list_tool_logs "${OPTION_OUTPUT}" "${directory}" "" "${configuration}"
      done
      IFS="${DEFAULT_IFS}" ; set +o noglob
   fi

   directories="`buildorder_log_dirs`"
   if [ ! -z "${directories}" ]
   then

      log_info "Buildorder logs"

      local name_configuration
      local name


      set -o noglob; IFS="
"
      for directory in ${directories}
      do
         IFS="${DEFAULT_IFS}" ; set +o noglob

         name_configuration="`fast_dirname "${directory#${BUILDORDER_BUILD_DIR}/}"`"
         name="${name_configuration%%/*}"
         configuration="${name_configuration#*/}"
         list_tool_logs "${OPTION_OUTPUT}" "${directory}" "${name}" "${configuration}"
      done
      IFS="${DEFAULT_IFS}" ; set +o noglob
   fi
}


build_log_command()
{
   log_entry "build_log_command" "$@"

   local cmd="$1"
   shift

   while :
   do
      case "$1" in
         -h*|--help|help)
            build_log_usage
         ;;

         -*)
            build_log_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local directory

   case "${OPTION_PROJECT_NAME}" in
      ''|'*')
         directory="${BUILD_DIR#${PWD}/}"
         directory="${directory}/${OPTION_CONFIGURATION}/.log/${OPTION_TOOL}.log"
         # https://stackoverflow.com/questions/2937407/test-whether-a-glob-matches-any-files
         if compgen -G ${directory} 2> /dev/null
         then
            exekutor "${cmd}" "$@" ${directory}
         else
            log_verbose "No project logs match"
         fi
      ;;
   esac

   case "${OPTION_PROJECT_NAME}" in
      '')
      ;;

      *)
         directory="${BUILDORDER_BUILD_DIR#${PWD}/}/${OPTION_PROJECT_NAME}"
         directory="${directory}/${OPTION_CONFIGURATION}/.log/${OPTION_TOOL}.log"
         if compgen -G ${directory} 2> /dev/null
         then
            exekutor "${cmd}" "$@" ${directory}
         else
            log_verbose "No buildorder logs match"
         fi
      ;;
   esac
}



#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
build_log_main()
{
   log_entry "build_log_main" "$@"

   local OPTION_PROJECT_NAME=""
   local OPTION_CONFIGURATION="*"
   local OPTION_TOOL="*"

   while :
   do
      case "$1" in
         -h*|--help|help)
            build_log_usage
         ;;

         -b|--build-dir)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            BUILD_DIR="$1"
         ;;

         -p|--project-name)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_NAME="$1"
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

         --dependency-build-dir)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_BUILDORDER_BUILD_DIR="$1"
         ;;

         -*)
            build_log_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   if [ -z "${BUILD_DIR}" ]
   then
      fail "Unknown build directory, specify with -b"
   fi

   local BUILDORDER_BUILD_DIR

   BUILDORDER_BUILD_DIR="${OPTION_BUILDORDER_BUILD_DIR:-${BUILD_DIR}/.buildorder}"

   local cmd

   cmd="$1"
   [ $# -ne  0 ] && shift

   case "${cmd}" in
      list)
         build_log_list "$@"
      ;;

      "")
         build_log_usage
      ;;

      *)
         build_log_command "$cmd" "$@"
      ;;
   esac
}
