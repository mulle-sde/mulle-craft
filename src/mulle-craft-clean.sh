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
MULLE_CRAFT_CLEAN_SH="included"


craft::clean::usage()
{
   [ "$#" -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} clean [options] [name]*

   Remove craft products. By default KITCHEN_DIR is removed, which will
   rebuild everything. You can also specify the names of the projects to clean
   and rebuild. There are four special names: "all",
   "craftorder", dependency", "project".

Options:
   --touch          : touch instead of clean craftorder to force recompile

Names:
   all              : clean kitchen folder
   craftorder       : clean craftorder only
   dependency       : clean dependency folder
   project          : clean main project

Environment:
   KITCHEN_DIR      : place for craft products and by-products
   DEPENDENCY_DIR   : place to put dependencies into (generally required)
EOF
  exit 1
}


craft::clean::remove_directory()
{
   log_entry "craft::clean::remove_directory" "$@"

   if [ -d "$1" ]
   then
      rmdir_safer "$1"
   else
      log_fluff "Clean target \"$1\" is not present"
   fi
}


craft::clean::remove_directories()
{
   log_entry "craft::clean::remove_directories" "$@"

   while [ $# -ne 0 ]
   do
      if [ ! -z "$1" ]
      then
         craft::clean::remove_directory "$1"
      fi
      shift
   done
}


#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
craft::clean::main()
{
   log_entry "craft::clean::main" "$@"

   local OPTION_DEPENDENCY="DEFAULT"
   local OPTION_TOUCH='NO'

   while :
   do
      case "$1" in
         -h*|--help|help)
            craft::clean::usage
         ;;

         --touch)
            OPTION_TOUCH='YES'
         ;;

         --no-memo-makeflags)
            shift
         ;;

         -*)
            craft::clean::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   [ -z "${KITCHEN_DIR}" ] && _internal_fail "KITCHEN_DIR is empty"

   if [ $# -eq 0 ]
   then
      log_verbose "Cleaning \"${KITCHEN_DIR}\" directory"

      craft::clean::remove_directory "${KITCHEN_DIR}"
      return $?
   fi

   include "craft::style"
   include "craft::path"

   # centralize this into mulle-craft-environment.sh

   while :
   do
      case "$1" in
         "build"|"kitchen")
            log_verbose "Cleaning \"$1\""

            craft::clean::remove_directory "${KITCHEN_DIR}"
            return
         ;;

         "craftorder")
            log_verbose "Cleaning \"${CRAFTORDER_KITCHEN_DIR}\" directory"

            craft::clean::remove_directory "${CRAFTORDER_KITCHEN_DIR}"
         ;;

         "dependency")
            log_verbose "Cleaning \"${DEPENDENCY_DIR}\" directory"

            craft::clean::remove_directory "${DEPENDENCY_DIR}"
         ;;

         "project")
            log_verbose "Cleaning project"

            shell_enable_nullglob
            for i in "${KITCHEN_DIR}"/*
            do
               if [ -d "${i}" ]
               then
                  craft::clean::remove_directory "${i}"
               fi
            done
            shell_disable_nullglob
         ;;

         "")
            break
         ;;

         *)
            local cleantarget

            cleantarget="$1"

            local escaped
            local donefile
#            local targets
#            local matches
#
#            r_escaped_grep_pattern "$1"
#            escaped="${RVAL}"
#
#            for donefile in "${CRAFTORDER_KITCHEN_DIR}"/*/.mulle-craft-built
#            do
#               matches="`rexekutor sed -s -e 's/^\([^;]*);/\1/' -e 's/^.*\//' "${donefile}"`"
#               r_add_line "${targets}" "${matches}"
#               targets="${RVAL}"
#            done
#
#            log_fluff "Available clean targets: `sort -u <<< "${targets}"`"
#
#            if ! rexekutor fgrep -x -s -q "${cleantarget}" <<< "${targets}"
#            then
#               fail "Unknown clean target \"${cleantarget}\".
#${C_VERBOSE}
#Available targets:
#   ${C_RESET}
#   `cat "${targets}" | sort -u | sed 's/^/   /'`
#"
#            fi

            log_verbose "Cleaning target \"${cleantarget}\""

            local directory

            craft::path::r_build_directory_name "${cleantarget}"
            directory="${RVAL}"

            if [ "${OPTION_TOUCH}" = 'NO' ]
            then
               shell_enable_nullglob
               craft::clean::remove_directories "${CRAFTORDER_KITCHEN_DIR}"/*/"${directory}" \
                                  "${CRAFTORDER_KITCHEN_DIR}"/*/*/"${directory}"
               shell_disable_nullglob
            fi

            r_escaped_sed_pattern "${cleantarget}"
            escaped="${RVAL}"

            .foreachfile donefile in "${DEPENDENCY_DIR}/etc"/craftorder-*
            .do
               if [ -f "${donefile}" ]
               then
                  include "craft::dependency"

                  # need to unprotect dependency_dir
                  craft::dependency::unprotect

                     inplace_sed -n -e "/^${escaped};/q;p" "${donefile}"
                     inplace_sed -n -e "/^.*\/${escaped};/q;p" "${donefile}"

                     # an empty donefile is bad for fgrep
                     if [ -z "`egrep -v '^#' "${donefile}"`" ]
                     then
                        remove_file_if_present "${donefile}"
                     fi

                  craft::dependency::protect
               fi
            .done

            log_debug "Done cleaning"
         ;;
      esac

      shift
   done
}
