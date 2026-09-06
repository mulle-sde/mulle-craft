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

   Show build logs. By default shows a step table of the most recent
   craft run: one line per build step (headers/compile/link, configure/
   build/install), in craftorder (causal build order), with a stable
   step number and the first error inlined for any failed project.
   Each craft run stores logs in a timestamped subdirectory, so previous
   runs are preserved and never mixed with the current one.

   Show the step table for the last run:

      ${MULLE_USAGE_NAME} log

   Show the full output of a single step from that table:

      ${MULLE_USAGE_NAME} log 9

   Show all logs of one project (main or dependency):

      ${MULLE_USAGE_NAME} log mulle-atexit

   Show all logs matching a wildcard pattern:

      ${MULLE_USAGE_NAME} log 'Mulle*'

   Show the old unfiltered dump instead of the step table:

      ${MULLE_USAGE_NAME} log --raw
      ${MULLE_USAGE_NAME} log --raw '*'

   Grep for errors across all projects:

      ${MULLE_USAGE_NAME} log '*' grep 'error:'

   Show warnings with 3 lines of context (file/line info):

      ${MULLE_USAGE_NAME} log warnings | grep -B3 'warning:'

   Or use the grep command form to get context lines directly:

      ${MULLE_USAGE_NAME} log '*' grep -B3 'warning:'

   Pipe log output to any tool (less, grep, awk, ...):

      ${MULLE_USAGE_NAME} log --raw | grep -B3 'warning:'
      ${MULLE_USAGE_NAME} log --raw | less

   Show logs from the previous run:

      ${MULLE_USAGE_NAME} log --run -1

   Show logs from a specific run:

      ${MULLE_USAGE_NAME} log --run 20260321T112305

Options:
   --all               : shortcut for project '*' (all projects)
   --raw               : unfiltered dump of all matching logfiles
   -c <configuration>  : restrict to configuration (default: last used)
   -t <tool>           : restrict to tool (cmake, make, configure, ...)
   --run <selector>    : which run to show: latest (default), -1 (previous),
                         -N (N runs ago), all, or a timestamp prefix

Project:
   *                   : all projects including dependencies
   ""                  : main project only (raw dump default)
   <name>              : specific dependency by name
   <glob>              : dependencies matching pattern (e.g. 'Mulle*')

Commands:
   <n>                 : show full output of step <n> from the step table
   diff                : diff latest run vs previous run (main project)
   errors              : show errors from latest run across all projects
   list                : list available log files
   runs                : list available run timestamps
   status              : show the step table (same as the bare default)
   warnings            : show warnings from latest run across all projects
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

   #
   # Guard against a non-existent basedir. Under zsh a failing glob
   # ("[0-9]*.*") aborts with a fatal "no matches found" (nomatch) that
   # 2>/dev/null can not suppress, and the literal pattern then leaks into
   # downstream find calls. dir_list_files expands the glob safely and only
   # when the directory exists.
   #
   if [ ! -d "${basedir}" ]
   then
      RVAL="${basedir}"
      return
   fi

   dirs="`dir_list_files "${basedir}" '[0-9]*.*' 'd'`"
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

   .foreachline i in `[ -d "${logdir}" ] && dir_list_files "${logdir}" "*.log" "f"`
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
# Read the craftorder file (if present) and emit the on-disk (filesystem-safe)
# names of dependencies in build order, one per line. This lets the status
# view present projects in the order they are actually built, instead of an
# arbitrary filesystem scan order.
#
# The craftorder file is written by mulle-sde/mulle-sourcetree during
# `reflect`, one absolute dependency source path (plus marks) per line, e.g.:
#    /path/to/stash/mulle-atexit;no-import,no-singlephase
#
craft::log::r_craftorder_names()
{
   log_entry "craft::log::r_craftorder_names" "$@"

   local craftorderfile

   craftorderfile="${CRAFTORDER_FILE}"
   if [ -z "${craftorderfile}" -o "${craftorderfile}" = "NONE" ]
   then
      craftorderfile="${DEPENDENCY_DIR:-dependency}/etc/craftorder"
   fi

   if [ ! -f "${craftorderfile}" ]
   then
      RVAL=""
      return 1
   fi

   include "craft::path"

   local line
   local filepath
   local name
   local result

   .foreachline line in `grep -E -v '^#' "${craftorderfile}" 2>/dev/null`
   .do
      filepath="${line%%;*}"
      [ -z "${filepath}" ] && .continue

      r_basename "${filepath}"
      name="${RVAL}"

      craft::path::r_build_directory_name "${name}"
      r_add_line "${result}" "${RVAL}"
      result="${RVAL}"
   .done

   RVAL="${result}"
}


#
# Grep warning/error lines from log files, skipping cmake info lines (-- prefix)
# and the =[PID]=> command echo lines.
#
# Matches both compiler-style diagnostics ("file.c:12: error: ...") and
# CMake-style diagnostics ("CMake Error at CMakeLists.txt:32 (message):"),
# which lack a trailing colon after "error"/"warning" and put the actual
# message on the following (indented) lines. For CMake-style hits we pull
# in a few lines of trailing context so the message is not lost.
#
craft::log::r_grep_diagnostics()
{
   local files="$1"   # newline-separated list of log files
   local pattern="$2" # 'warning' or 'error' etc. (no trailing colon)

   local result
   local f
   local hit
   local found='NO'
   local cmake_hit

   .foreachline f in ${files}
   .do
      [ -f "${f}" ] || .continue
      [ -s "${f}" ] || .continue

      # 1) compiler-style: "...error: message" (colon required)
      hit="$(grep -E "${pattern}:" "${f}" \
         | grep -v '^--' \
         | grep -v '^=\[' \
         | grep -v '^\[' )"

      # 2) cmake-style: "CMake Error at ..." / "CMake Warning ..." with
      #    the message body on the next few indented/blank lines.
      cmake_hit="$(grep -E -A5 "^CMake (${pattern})" "${f}" 2>/dev/null)"

      if [ ! -z "${hit}" ] || [ ! -z "${cmake_hit}" ]
      then
         found='YES'
         if [ ! -z "${result}" ]
         then
            result="${result}"$'\n'
         fi
         if [ ! -z "${hit}" ]
         then
            result="${result}${hit}"
         fi
         if [ ! -z "${cmake_hit}" ]
         then
            [ ! -z "${result}" ] && result="${result}"$'\n'
            result="${result}${cmake_hit}"
         fi
      fi
   .done

   if [ "${found}" = 'NO' ]
   then
      RVAL=""
      return 1
   fi

   RVAL="${result}"
}


#
# Determine the build phase and operation for a single log file.
#
# The operation (configure/build/install/run/...) is read directly off the
# filename, since mulle-make's plugins already name their logs after the
# tool invocation that produced them (make::common::r_build_log_name),
# e.g. 00.configure.log, 01.make.log, 00.cmake.log, 01.cmake.log, ...
# This works uniformly across all mulle-make plugins (cmake, make,
# configure, autoconf, meson, script, xcodebuild), not just cmake.
#
# The phase (HEADERS/COMPILE/LINK) is a cmake-only concept: every other
# plugin explicitly refuses --phase (see e.g. plugins/configure.sh,
# plugins/make.sh). So phase is only ever populated when the log's tool
# is cmake and its recorded command line happens to carry
# -DMULLE_MAKE_PHASE=..., and is empty for every other tool. It is not
# guessed or carried forward for non-cmake tools.
#
craft::log::r_step_info()
{
   log_entry "craft::log::r_step_info" "$@"

   local logfile="$1"

   local tool

   r_extensionless_basename "${logfile}"     # NN.tool
   tool="${RVAL#*.}"                         # tool

   local operation

   case "${tool}" in
      cmake)
         local firstline

         firstline="$(head -1 "${logfile}" 2>/dev/null)"

         case "${firstline}" in
            *' --build '*|*' --build ')  operation="build" ;;
            *' --install '*)             operation="install" ;;
            *)                           operation="configure" ;;
         esac
      ;;

      *)
         # for every other plugin, the tool name itself is the operation
         # (configure, make, autoconf, meson, ninja, script, xcodebuild, ...)
         operation="${tool}"
      ;;
   esac

   local phase

   if [ "${tool}" = "cmake" ]
   then
      firstline="${firstline:-$(head -1 "${logfile}" 2>/dev/null)}"

      phase="${firstline#*MULLE_MAKE_PHASE=}"
      case "${phase}" in
         "${firstline}")
            phase=""
         ;;
         *)
            phase="${phase%% *}"
            phase="${phase%%\'*}"
         ;;
      esac
   fi

   RVAL="${phase};${operation}"
}


#
# Return 0 and the first diagnostic line (with a couple of lines of context
# for cmake-style multi-line errors) found in a single log file, or 1 if
# the file is clean.
#
craft::log::r_first_diagnostic()
{
   log_entry "craft::log::r_first_diagnostic" "$@"

   local logfile="$1"

   [ -s "${logfile}" ] || return 1

   local hit

   hit="$(grep -m1 -E -A2 '^CMake (Error|Warning)' "${logfile}" 2>/dev/null)"
   if [ -z "${hit}" ]
   then
      hit="$(grep -m1 -E '[Ee]rror:|[Ww]arning:' "${logfile}" \
         | grep -v '^--' | grep -v '^=\[' | grep -v '^\[' )"
   fi

   [ -z "${hit}" ] && return 1

   RVAL="${hit}"
   return 0
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

         files="`[ -d "${logdir}" ] && dir_list_files "${logdir}" "*.log" "f"`"
         if craft::log::r_grep_diagnostics "${files}" "${pattern}"
         then
            printf "%s\n" "${C_RESET_BOLD}${name}:${C_RESET}"
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

         files="`[ -d "${logdir}" ] && dir_list_files "${logdir}" "*.log" "f"`"
         if craft::log::r_grep_diagnostics "${files}" "${pattern}"
         then
            printf "%s\n" "${C_RESET_BOLD}${PROJECT_NAME:-project}:${C_RESET}"
            printf "%s\n" "${RVAL}"
         fi
      .done
   fi
}


#
#
# Print the numbered step table (phase, operation, size) for a single
# project's latest run, and if the project FAILed, the first diagnostic
# found in that run. "index" is a running counter across the whole status
# view, so each step can be addressed later as `mulle-sde log <n>`.
#
# Sets RVAL to the updated index and NR_STEP_LOGFILES/NR_STEP_INDEX arrays
# (STEP_INDEX_<n>=logfile) so callers can resolve `log <n>` afterwards.
#
craft::log::r_print_project_steps()
{
   log_entry "craft::log::r_print_project_steps" "$@"

   local name="$1"
   local logdir="$2"
   local statuscode="$3"
   local index="$4"

   local files
   local f
   local phase
   local operation
   local info
   local lastphase
   local size

   files="`[ -d "${logdir}" ] && dir_list_files "${logdir}" "*.log" "f"`"

   [ -z "${files}" ] && { RVAL="${index}"; return; }

   local firsthit
   local firsthit_index

   .foreachline f in ${files}
   .do
      [ -s "${f}" ] || .continue

      craft::log::r_step_info "${f}"
      info="${RVAL}"
      phase="${info%%;*}"
      operation="${info#*;}"

      if [ -z "${phase}" ]
      then
         phase="${lastphase}"
      else
         lastphase="${phase}"
      fi

      size="$(file_size_in_bytes "${f}")"

      index=$(( index + 1 ))

      # remember mapping index -> logfile for `log <n>` lookups. This is a
      # fresh index file per status() run (truncated by the caller before
      # the first step), since indices are only meaningful for one call.
      printf "%s\t%s\n" "${index}" "${f}" >> "${MULLE_CRAFT_LOG_STEP_INDEX_FILE:-/dev/null}"

      if craft::log::r_first_diagnostic "${f}" && [ -z "${firsthit}" ]
      then
         firsthit="${RVAL}"
         firsthit_index="${index}"
      fi

      printf "  %3s  %-24s %-9s %-10s %6s bytes\n" \
         "${index}" \
         "${name}" \
         "${phase:--}" \
         "${operation}" \
         "${size:-0}"
   .done

   if [ ! -z "${firsthit}" ]
   then
      local firsthit_line1
      local firsthit_line2

      firsthit_line1="$(printf '%s\n' "${firsthit}" | head -1)"
      firsthit_line2="$(printf '%s\n' "${firsthit}" | sed -n '2p')"

      r_trim_whitespace "${firsthit_line2}"
      firsthit_line2="${RVAL}"

      if [ ! -z "${firsthit_line2}" ]
      then
         printf "%s\n" "${C_ERROR}       -> step ${firsthit_index}: ${firsthit_line1}${C_RESET}"
         printf "%s\n" "${C_ERROR}          ${firsthit_line2}${C_RESET}"
      else
         printf "%s\n" "${C_ERROR}       -> step ${firsthit_index}: ${firsthit_line1}${C_RESET}"
      fi
   fi

   RVAL="${index}"
}


#
# Build the ordered list of "name<TAB>directory" pairs for all craftorder
# dependency .log directories: craftorder-file order first, then any
# leftover directories the craftorder file doesn't know about (stale file,
# or CRAFTORDER_FILE not found), in filesystem scan order.
#
craft::log::r_ordered_dependency_logdirs()
{
   log_entry "craft::log::r_ordered_dependency_logdirs" "$@"

   local directories
   local directory
   local name

   local map_names=""
   local map_dirs=""

   directories="`craft::log::craftorder_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         r_dirname "${directory#${CRAFTORDER_KITCHEN_DIR}/}"
         name="${RVAL##*/}"

         r_add_line "${map_names}" "${name}"
         map_names="${RVAL}"
         r_add_line "${map_dirs}" "${directory}"
         map_dirs="${RVAL}"
      .done
   fi

   local orderednames

   craft::log::r_craftorder_names
   orderednames="${RVAL}"

   local result=""
   local seen=""
   local wantname
   local n
   local i

   if [ ! -z "${orderednames}" ]
   then
      .foreachline wantname in ${orderednames}
      .do
         i=0
         .foreachline n in ${map_names}
         .do
            i=$(( i + 1 ))
            [ "${n}" = "${wantname}" ] || .continue

            r_add_line "${seen}" "${wantname}"
            seen="${RVAL}"

            r_line_at_index "${map_dirs}" $(( i - 1 ))
            directory="${RVAL}"

            r_betwixt $'\t' "${wantname}" "${directory}"
            r_add_line "${result}" "${RVAL}"
            result="${RVAL}"
            break
         .done
      .done
   fi

   if [ ! -z "${map_names}" ]
   then
      i=0
      .foreachline n in ${map_names}
      .do
         i=$(( i + 1 ))

         if [ ! -z "${seen}" ] && find_line "${seen}" "${n}"
         then
            .continue
         fi

         r_line_at_index "${map_dirs}" $(( i - 1 ))
         directory="${RVAL}"

         r_betwixt $'\t' "${n}" "${directory}"
         r_add_line "${result}" "${RVAL}"
         result="${RVAL}"
      .done
   fi

   RVAL="${result}"
}


#
# The default `mulle-sde log` view: one line per build step, in craftorder
# (i.e. causal build order, not filesystem/mtime order), each with a stable
# numeric index so a single step can be inspected with `mulle-sde log <n>`.
# Failed projects get the first diagnostic line inlined; a final summary
# line gives the overall run verdict.
#
craft::log::status()
{
   log_entry "craft::log::status" "$@"

   local index=0
   local total=0
   local failed=0
   local run_timestamp

   # index file mapping displayed step numbers to actual logfile paths;
   # rewritten on every status() run since the numbering is only stable
   # for the run that produced it
   MULLE_CRAFT_LOG_STEP_INDEX_FILE="${KITCHEN_DIR}/.log-step-index"
   redirect_exekutor "${MULLE_CRAFT_LOG_STEP_INDEX_FILE}" printf ""

   printf "  %3s  %-24s %-9s %-10s %s\n" "#" "project" "phase" "step" "size"

   local pairs
   local pair
   local name
   local directory
   local logdir
   local kitchendir
   local statuscode

   craft::log::r_ordered_dependency_logdirs
   pairs="${RVAL}"

   if [ ! -z "${pairs}" ]
   then
      .foreachline pair in ${pairs}
      .do
         r_split "${pair}" $'\t'
         name="${RVAL[0]}"
         directory="${RVAL[1]}"

         craft::log::r_latest_logdir "${directory}"
         logdir="${RVAL}"

         r_basename "${logdir}"
         [ -z "${run_timestamp}" ] && run_timestamp="${RVAL}"

         kitchendir="${directory%/.log}"
         statuscode="`cat "${kitchendir}/.status" 2>/dev/null`"

         total=$(( total + 1 ))
         [ "${statuscode}" != "0" ] && [ ! -z "${statuscode}" ] && failed=$(( failed + 1 ))

         craft::log::r_print_project_steps "${name}" "${logdir}" "${statuscode}" "${index}"
         index="${RVAL}"
      .done
   fi

   # main project, always last
   local directories

   directories="`craft::log::project_log_dirs`"
   if [ ! -z "${directories}" ]
   then
      .foreachline directory in ${directories}
      .do
         name="${PROJECT_NAME:-project}"

         craft::log::r_latest_logdir "${directory}"
         logdir="${RVAL}"

         r_basename "${logdir}"
         [ -z "${run_timestamp}" ] && run_timestamp="${RVAL}"

         kitchendir="${directory%/.log}"
         statuscode="`cat "${kitchendir}/.status" 2>/dev/null`"

         total=$(( total + 1 ))
         [ "${statuscode}" != "0" ] && [ ! -z "${statuscode}" ] && failed=$(( failed + 1 ))

         craft::log::r_print_project_steps "${name}" "${logdir}" "${statuscode}" "${index}"
         index="${RVAL}"
      .done
   else
      printf "\n  (main project not crafted for configuration \"${OPTION_CONFIGURATION}\")\n"
   fi

   echo

   if [ "${failed}" -gt 0 ]
   then
      printf "%s\n" "${C_ERROR}run ${run_timestamp:-?}: ${failed} of ${total} projects FAILED${C_RESET}"
   else
      printf "%s\n" "${C_VERBOSE}run ${run_timestamp:-?}: ${total} of ${total} projects OK${C_RESET}"
   fi

   log_vibe "${MULLE_USAGE_NAME} log <n>            full output of step <n>"
   log_vibe "${MULLE_USAGE_NAME} log <project>      all steps of one project"
   log_vibe "${MULLE_USAGE_NAME} log --raw          unfiltered dump"
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
   local directories directory depname found logdir i rundir

   directories="`craft::log::craftorder_log_dirs`"
   .foreachline directory in ${directories}
   .do
      r_dirname "${directory#${CRAFTORDER_KITCHEN_DIR}/}"
      depname="${RVAL##*/}"
      case "${depname}" in ${name_fs}) ;; *) .continue ;; esac

      printf "%s\n" "${C_RESET_BOLD}${depname}${C_RESET}"
      craft::log::r_latest_logdir "${directory}"

      .foreachline rundir in ${RVAL}
      .do
         .foreachfile i in "${rundir}/"*.${OPTION_TOOL:-*}.log
         .do
            [ -e "${i}" ] || .continue
            [ -s "${i}" ] || .continue
            printf "%s\n" "${C_RESET_BOLD}${i}:${C_RESET}"
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
      [ -d "${directory}" ] || .continue
      dir_list_files "${directory}" "$@"
   .done
}



craft::log::project()
{
   log_entry "craft::log::project" "$@"

   local cmd="$1"

   [ $# -ne 0 ] && shift

   printf "%s\n" "${C_RESET_BOLD}${PROJECT_NAME:-${PWD}}${C_RESET}"

   local configuration

   configuration="${OPTION_CONFIGURATION}"
   configuration="${configuration:-Release}"

   local logfiles
   local directory
   local rundir
   local i

   directory="${KITCHEN_DIR#${PWD}/}"

   shell_enable_nullglob
   shell_enable_glob

   local found_logbasedir='NO'

   .foreachfile logbasedir in "${directory}"/${configuration}/.log
   .do
      [ -d "${logbasedir}" ] || .continue

      found_logbasedir='YES'
      craft::log::r_latest_logdir "${logbasedir}"

      .foreachline rundir in ${RVAL}
      .do
         log_debug "Log dir: ${rundir}"
         logfiles="`craft::log::directories_list_files "${rundir}/" -- "*.${OPTION_TOOL:-*}.log" `"

         if [ ! -z "${logfiles}" ]
         then
            .foreachline i in ${logfiles}
            .do
               [ -s "${i}" ] || .continue
               printf "%s\n" "${C_RESET_BOLD}${i}:${C_RESET}"
               exekutor "${cmd}" "$@" "${i}"
            .done
         else
            log_verbose "No project logs match"
         fi
      .done
   .done
   shell_disable_nullglob

   if [ "${found_logbasedir}" = 'NO' ]
   then
      printf "%s\n" "  (main project not crafted for configuration \"${configuration}\")"
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
# `mulle-sde log <n>` - show the full output of step <n> from the last
# `status` view. Relies on the index file status() writes; if it's absent
# or stale (e.g. a craft happened in between), say so instead of guessing.
#
craft::log::step()
{
   log_entry "craft::log::step" "$@"

   local index="$1"
   local cmd="${2:-cat}"

   [ $# -gt 0 ] && shift
   [ $# -gt 0 ] && shift

   local indexfile
   local logfile

   indexfile="${KITCHEN_DIR}/.log-step-index"

   if [ ! -f "${indexfile}" ]
   then
      fail "No step index available. Run ${C_RESET_BOLD}mulle-sde log${C_ERROR} first."
   fi

   logfile="$(awk -F'\t' -v n="${index}" '$1 == n { print $2 }' "${indexfile}")"

   if [ -z "${logfile}" ]
   then
      fail "No such step \"${index}\". Run ${C_RESET_BOLD}mulle-sde log${C_ERROR} to see valid step numbers."
   fi

   if [ ! -f "${logfile}" ]
   then
      fail "Step \"${index}\" refers to \"${logfile}\", which no longer exists. \
Run ${C_RESET_BOLD}mulle-sde log${C_ERROR} again to refresh step numbers."
   fi

   printf "%s\n" "${C_RESET_BOLD}${logfile}:${C_RESET}"
   exekutor "${cmd}" "$@" "${logfile}"
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
   local OPTION_RAW='NO'

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

         --raw)
            OPTION_RAW='YES'
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
         craft::log::show_diagnostics '[Ee]rror'
      ;;

      warnings)
         craft::log::show_diagnostics '[Ww]arning'
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

      summary|status)
         shift
         craft::log::status "$@"
      ;;

      [0-9]*)
         local step="$1"

         shift
         craft::log::step "${step}" "$@"
      ;;

      '')
         if [ "${OPTION_RAW}" = 'YES' ]
         then
            craft::log::command "$@"
         else
            craft::log::status
         fi
      ;;

      '*')
         if [ $# -le 1 ] && [ "${OPTION_RAW}" != 'YES' ]
         then
            craft::log::status
         else
            craft::log::command "$@"
         fi
      ;;

      *)
         craft::log::command "$@"
      ;;
   esac
}

