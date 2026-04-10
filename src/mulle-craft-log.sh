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

   Show build logs. By default shows only the most recent craft run.
   Each craft run stores logs in a timestamped subdirectory, so previous
   runs are preserved and never mixed with the current one.

   Show latest logs for the main project:

      ${MULLE_USAGE_NAME} log

   Show all logs (all projects, latest run):

      ${MULLE_USAGE_NAME} log '*'

   Show all logs across all projects and all runs (e.g. incremental builds):

      ${MULLE_USAGE_NAME} log --all --run all

   Show logs matching a wildcard pattern:

      ${MULLE_USAGE_NAME} log 'Mulle*'

   Grep for errors across all projects:

      ${MULLE_USAGE_NAME} log '*' grep 'error:'

   Show warnings with 3 lines of context (file/line info):

      ${MULLE_USAGE_NAME} log warnings | grep -B3 'warning:'

   Or use the grep command form to get context lines directly:

      ${MULLE_USAGE_NAME} log '*' grep -B3 'warning:'

   Pipe log output to any tool (less, grep, awk, ...):

      ${MULLE_USAGE_NAME} log | grep -B3 'warning:'
      ${MULLE_USAGE_NAME} log | less

   Show logs from the previous run:

      ${MULLE_USAGE_NAME} log --run -1

   Show logs from a specific run:

      ${MULLE_USAGE_NAME} log --run 20260321T112305

Options:
   --all               : shortcut for project '*' (all projects)
   -c <configuration>  : restrict to configuration (default: last used)
   -t <tool>           : restrict to tool (cmake, make, configure, ...)
   --run <selector>    : which run to show: latest (default), -1 (previous),
                         -N (N runs ago), all, or a timestamp prefix

Project:
   *                   : all projects including dependencies
   ""                  : main project only (default)
   <name>              : specific dependency by name
   <glob>              : dependencies matching pattern (e.g. 'Mulle*')

Commands:
   list                : list available log files
   runs                : list available run timestamps
   errors              : show errors from latest run across all projects
   warnings            : show warnings from latest run across all projects
   summary             : one-line status per project (name, run, OK/FAIL, warnings)
   diff                : diff latest run vs previous run (main project)
   <tool> ...          : run any command on the log files (cat, grep, ...)

EOF
  exit 1
}


#
# Given a .log base directory, return the latest timestamped subdirectory.
# Falls back to basedir itself for backward compat with old flat layout.
# Respects OPTION_RUN: latest (default), -N (relative), or timestamp prefix.
#
craft::log::r_latest_logdir()
{
   log_entry "craft::log::r_latest_logdir" "$@"

   local basedir="$1"

   local dirs

   dirs="$(ls -1d "${basedir}"/[0-9]*.* 2>/dev/null)"
   if [ -z "${dirs}" ]
   then
      RVAL="${basedir}"
      return
   fi

   case "${OPTION_RUN:-latest}" in
      ''|'latest')
         RVAL="$(printf '%s\n' "${dirs}" | tail -1)"
      ;;

      'all')
         RVAL="${dirs}"
      ;;

      '-'[0-9]*)
         local offset count index
         offset="${OPTION_RUN#-}"
         count="$(printf '%s\n' "${dirs}" | grep -c .)"
         index=$(( count - offset ))
         [ "${index}" -lt 1 ] && index=1
         RVAL="$(printf '%s\n' "${dirs}" | sed -n "${index}p")"
      ;;

      *)
         RVAL="$(printf '%s\n' "${dirs}" | grep "/${OPTION_RUN}" | tail -1)"
         if [ -z "${RVAL}" ]
         then
            fail "No log run matching \"${OPTION_RUN}\""
         fi
      ;;
   esac
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


craft::log::runs()
{
   log_entry "craft::log::runs" "$@"

   local directories
   local directory

   directories="`craft::log::project_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         ls -1d "${directory}"/[0-9]*.* 2>/dev/null \
         | sed "s|.*\.log/||" \
         | sed "s|^|${directory#${KITCHEN_DIR}/}: |"
      .done
   fi

   directories="`craft::log::craftorder_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         ls -1d "${directory}"/[0-9]*.* 2>/dev/null \
         | sed "s|.*\.log/||" \
         | sed "s|^|${directory#${CRAFTORDER_KITCHEN_DIR}/}: |"
      .done
   fi
}


#
# Grep warning/error lines from log files, skipping cmake info lines (-- prefix)
# and the =[PID]=> command echo lines.
#
craft::log::r_grep_diagnostics()
{
   local files="$1"   # newline-separated list of log files
   local pattern="$2" # 'warning\|error' or 'error' etc.

   local result
   local f

   .foreachline f in ${files}
   .do
      [ -f "${f}" ] || .continue

      result="${result}$(grep -E "${pattern}" "${f}" \
         | grep -v '^--' \
         | grep -v '^=\[' \
         | grep -v '^\[' )"$'\n'
   .done

   RVAL="${result}"
}


#
# Print warning/error lines from the latest run of all projects,
# prefixed with the project name.
#
craft::log::show_diagnostics()
{
   log_entry "craft::log::show_diagnostics" "$@"

   local pattern="$1"   # grep -E pattern

   local directories directory logdir files name

   # craftorder deps first
   directories="`craft::log::craftorder_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         craft::log::r_latest_logdir "${directory}"
         logdir="${RVAL}"

         r_dirname "${directory#${CRAFTORDER_KITCHEN_DIR}/}"
         name="${RVAL##*/}"

         files="`dir_list_files "${logdir}" "*.log" "f"`"
         craft::log::r_grep_diagnostics "${files}" "${pattern}"
         if [ ! -z "${RVAL}" ]
         then
            log_info "${name}:"
            printf "%s\n" "${RVAL}"
         fi
      .done
   fi

   # main project
   directories="`craft::log::project_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         craft::log::r_latest_logdir "${directory}"
         logdir="${RVAL}"

         files="`dir_list_files "${logdir}" "*.log" "f"`"
         craft::log::r_grep_diagnostics "${files}" "${pattern}"
         if [ ! -z "${RVAL}" ]
         then
            log_info "${PROJECT_NAME:-project}:"
            printf "%s\n" "${RVAL}"
         fi
      .done
   fi
}


#
# One-line summary per project: name, run timestamp, status, warning count.
#
craft::log::summary()
{
   log_entry "craft::log::summary" "$@"

   local directories directory logdir kitchendir name timestamp status warnings files

   local all_dirs=""

   # collect craftorder dirs with their kitchendir
   directories="`craft::log::craftorder_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         r_dirname "${directory#${CRAFTORDER_KITCHEN_DIR}/}"
         name="${RVAL##*/}"

         craft::log::r_latest_logdir "${directory}"
         logdir="${RVAL}"

         r_basename "${logdir}"
         timestamp="${RVAL:-none}"

         kitchendir="${directory%/.log}"
         status="`cat "${kitchendir}/.status" 2>/dev/null`"
         if [ -z "${status}" ]
         then
            status="?"
         elif [ "${status}" = "0" ]
         then
            status="OK"
         else
            status="FAIL(${status})"
         fi

         files="`dir_list_files "${logdir}" "*.log" "f"`"
         craft::log::r_grep_diagnostics "${files}" '[Ww]arning:'
         warnings="$(printf '%s\n' "${RVAL}" | grep -c .)"

         printf "%-40s  %-20s  %-10s  %s warnings\n" \
            "${name}" "${timestamp}" "${status}" "${warnings}"
      .done
   fi

   # main project
   directories="`craft::log::project_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         name="${PROJECT_NAME:-project}"

         craft::log::r_latest_logdir "${directory}"
         logdir="${RVAL}"

         r_basename "${logdir}"
         timestamp="${RVAL:-none}"

         kitchendir="${directory%/.log}"
         status="`cat "${kitchendir}/.status" 2>/dev/null`"
         if [ -z "${status}" ]
         then
            status="?"
         elif [ "${status}" = "0" ]
         then
            status="OK"
         else
            status="FAIL(${status})"
         fi

         files="`dir_list_files "${logdir}" "*.log" "f"`"
         craft::log::r_grep_diagnostics "${files}" '[Ww]arning:'
         warnings="$(printf '%s\n' "${RVAL}" | grep -c .)"

         printf "%-40s  %-20s  %-10s  %s warnings\n" \
            "${name}" "${timestamp}" "${status}" "${warnings}"
      .done
   fi
}


craft::log::list()
{
   log_entry "craft::log::list" "$@"

   local directory
   local configuration
   local OPTION_OUTPUT='DEFAULT'

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

         craft::log::r_latest_logdir "${directory}"
         craft::log::list_tool_logs "${OPTION_OUTPUT}" "${RVAL}" "" "${configuration}"
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

         craft::log::r_latest_logdir "${directory}"
         craft::log::list_tool_logs "${OPTION_OUTPUT}" "${RVAL}" "${name}" "${configuration}"
      .done
   fi
}


craft::log::craftorders()
{
   log_entry "craft::log::craftorders" "$@"

   local name="$1"
   local cmd="$2"

   shift 2

   # Translate user-supplied name to the filesystem-safe form used as the
   # build directory name.
   local name_fs

   case "${name}" in
      ''|'*')
         name_fs="${name}"
      ;;
      *)
         include "craft::path"
         craft::path::r_build_directory_name "${name}"
         name_fs="${RVAL}"
      ;;
   esac

   # Iterate all craftorder log dirs and filter by name pattern.
   # We always do this per-project so r_latest_logdir gets a concrete path,
   # not a glob that would mix timestamps across projects.
   local directories directory depname found logdir i

   directories="`craft::log::craftorder_log_dirs`"
   .foreachline directory in ${directories}
   .do
      r_dirname "${directory#${CRAFTORDER_KITCHEN_DIR}/}"
      depname="${RVAL##*/}"
      case "${depname}" in ${name_fs}) ;; *) .continue ;; esac

      log_info "${depname}"
      craft::log::r_latest_logdir "${directory}"

      local rundir
      .foreachline rundir in ${RVAL}
      .do
         .foreachfile i in "${rundir}/"*.${OPTION_TOOL:-*}.log
         .do
            [ -e "${i}" ] || .continue
            log_info "${C_RESET_BOLD}${i}:"
            exekutor "${cmd}" "$@" "${i}"
            found='YES'
         .done
      .done
   .done

   [ -z "${found}" ] && log_verbose "No craftorder logs match for \"${name}\""
}


craft::log::directories_list_files()
{
   local directories

   while [ $# -ne 0 ]
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

   .foreachfile logbasedir in "${directory}"/${configuration}/.log
   .do
      craft::log::r_latest_logdir "${logbasedir}"

      local rundir
      .foreachline rundir in ${RVAL}
      .do
         log_debug "Log dir: ${rundir}"
         logfiles="`craft::log::directories_list_files "${rundir}/" -- "*.${OPTION_TOOL:-*}.log" `"

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
      .done
   .done
   shell_disable_nullglob
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
   local OPTION_RUN="latest"
   local OPTION_ALL='NO'

   while [ $# -ne 0 ]
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

         -r|--run)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_RUN="$1"
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

         --all)
            OPTION_ALL='YES'
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

   if [ "${OPTION_ALL}" = 'YES' ]
   then
      set -- '*' "$@"
   fi

   if [ -z "${KITCHEN_DIR}" ]
   then
      fail "Unknown kitchen directory, specify with -k"
   fi

   case "$1" in
      list)
         shift
         craft::log::list "$@"
      ;;

      runs)
         craft::log::runs
      ;;

      errors)
         craft::log::show_diagnostics '[Ee]rror:'
      ;;

      warnings)
         craft::log::show_diagnostics '[Ww]arning:'
      ;;

      diff)
         local prev_dir cur_dir

         # get latest and previous for main project log dir
         directories="`craft::log::project_log_dirs`"
         .foreachline directory in ${directories}
         .do
            cur_dir="$(ls -1d "${directory}"/[0-9]*.* 2>/dev/null | tail -1)"
            prev_dir="$(ls -1d "${directory}"/[0-9]*.* 2>/dev/null | tail -2 | head -1)"
         .done

         if [ -z "${prev_dir}" -o "${prev_dir}" = "${cur_dir}" ]
         then
            log_warning "Only one run available, nothing to diff"
         else
            diff -u \
               <(cat "${prev_dir}"/*.log 2>/dev/null) \
               <(cat "${cur_dir}"/*.log 2>/dev/null)
         fi
      ;;

      summary)
         craft::log::summary
      ;;

      *)
         craft::log::command "$@"
      ;;
   esac
}

