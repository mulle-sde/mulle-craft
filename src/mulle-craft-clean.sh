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
MULLE_CRAFT_CLEAN_SH='included'


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
   --platform <p>   : platform to clean for
   --configuration <c> : configuration to clean for
   --sdk <s>        : sdk to clean for

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



craft::clean::remove_donefiles()
{
   log_entry "craft::clean::remove_donefiles" "$@"

   local donefiles="$1"

   local donefile

   if [ ! -z "${donefiles}" ]
   then
      include "craft::dependency"

      craft::dependency::unprotect

      .foreachline donefile in ${donefiles}
      .do
         remove_file_if_present "${donefile}"
      .done

      craft::dependency::protect
   fi
}


craft::clean::remove_item_from_donefiles()
{
   log_entry "craft::clean::remove_item_from_donefiles" "$@"

   #
   # these file are centralized
   #
   local cleantarget="$1"
   local donefiles="$2"

   local escaped

   r_escaped_sed_pattern "${cleantarget}"
   escaped="${RVAL}"

   local donefile

   if [ ! -z "${donefiles}" ]
   then
      include "craft::dependency"

      craft::dependency::unprotect

      .foreachline donefile in ${donefiles}
      .do
         # need to unprotect dependency_dir
         inplace_sed -n -e "/^${escaped};/q;p" "${donefile}"
         inplace_sed -n -e "/^.*\/${escaped};/q;p" "${donefile}"

         # an empty donefile is bad for grep -F
         if [ -z "`grep -E -v '^#' "${donefile}"`" ]
         then
            remove_file_if_present "${donefile}"
         fi
      .done

      craft::dependency::protect
   fi
}


craft::clean::remove_dependency_directory()
{
   log_entry "craft::clean::remove_dependency_directory" "$@"

   local l_dependency_dir="$1"

   if [ -d "${l_dependency_dir}" ]
   then
      include "craft::dependency"

      craft::dependency::unprotect

      craft::dependency::set_state "incomplete"

      rmdir_safer "${l_dependency_dir}"

      craft::dependency::protect
   else
      log_fluff "Dependency directory \"$1\" is not present"
   fi
}


#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
craft::clean::main()
{
   log_entry "craft::clean::main" "$@"

   local OPTION_DEPENDENCY='DEFAULT'
   local OPTION_TOUCH='NO'

   local OPTION_CONFIGURATION='Debug'
   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_SDK='Default'
   local OPTION_STYLE='auto'
   local OPTION_GLOBAL='YES'

   while [ $# -ne 0 ]
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

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
            OPTION_GLOBAL='NO'
         ;;

         --platform)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
            OPTION_GLOBAL='NO'
         ;;

         --sdk)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
            OPTION_GLOBAL='NO'
         ;;

         --style)
            [ $# -eq 1 ] && craft::style::usage "Missing argument to \"$1\""
            shift

            OPTION_STYLE="$1"
            OPTION_GLOBAL='NO'
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

   include "craft::style"
   include "craft::path"

   # zsh upper/lower problem
   local l_dependency_dir
   local l_kitchen_dir
   local l_craftorder_kitchen_dir
   local stylesubdir

   if [ "${OPTION_GLOBAL}" = 'YES' ]
   then
      l_dependency_dir="${DEPENDENCY_DIR}"
      l_kitchen_dir="${KITCHEN_DIR}"
      l_craftorder_kitchen_dir="${CRAFTORDER_KITCHEN_DIR}"
      stylesubdir="${RVAL}"
   else
      craft::path::r_dependencydir "${OPTION_SDK}" \
                                   "${OPTION_PLATFORM}" \
                                   "${OPTION_CONFIGURATION}" \
                                   "${OPTION_STYLE}" \
                                   "${DEPENDENCY_DIR}"
      l_dependency_dir="${RVAL}"


      craft::path::r_mainproject_kitchendir "${OPTION_SDK}" \
                                            "${OPTION_PLATFORM}" \
                                            "${OPTION_CONFIGURATION}" \
                                            "${OPTION_STYLE}" \
                                            "${KITCHEN_DIR}"
      l_kitchen_dir="${RVAL}"


      craft::style::r_get_sdk_platform_configuration_string "${OPTION_SDK}" \
                                                            "${OPTION_PLATFORM}" \
                                                            "${OPTION_CONFIGURATION}" \
                                                            "${OPTION_STYLE}"
      stylesubdir="${RVAL}"

      r_filepath_concat "${CRAFTORDER_KITCHEN_DIR}" "${stylesubdir}"
      l_craftorder_kitchen_dir="${RVAL}"
   fi

   log_setting "DEPENDENCY_DIR           : ${DEPENDENCY_DIR}"
   log_setting "dependency_dir           : ${l_dependency_dir}"
   log_setting "KITCHEN_DIR              : ${KITCHEN_DIR}"
   log_setting "kitchen_dir              : ${l_kitchen_dir}"
   log_setting "CRAFTORDER_KITCHEN_DIR   : ${CRAFTORDER_KITCHEN_DIR}"
   log_setting "craftorder_kitchen_dir   : ${l_craftorder_kitchen_dir}"

   if [ $# -eq 0 ]
   then
      log_verbose "Cleaning \"${l_kitchen_dir}\" directory"

      craft::clean::remove_directory "${l_kitchen_dir}"
      return $?
   fi

   local donefiles

   while [ $# -ne 0 ]
   do
      case "$1" in
         "build"|"kitchen")
            log_verbose "Cleaning \"$1\""

            craft::clean::remove_directory "${l_kitchen_dir}"
            return
         ;;

         "craftorder")
            log_verbose "Cleaning \"${l_dependency_dir}\" directory"

            craft::clean::remove_dependency_directory  "${l_dependency_dir}"

            log_verbose "Cleaning \"${l_craftorder_kitchen_dir}\" directory"

            craft::clean::remove_directory "${l_craftorder_kitchen_dir}"


            include "craft::donefile"

            craft::donefile::r_list_donefile_paths "${OPTION_SDK}" \
                                                   "${OPTION_PLATFORM}" \
                                                   "${OPTION_CONFIGURATION}"
            donefiles="${RVAL}"
            craft::clean::remove_donefiles "${donefiles}"
         ;;

         "dependency")
            log_verbose "Cleaning \"${l_dependency_dir}\" directory"

            craft::clean::remove_dependency_directory "${l_dependency_dir}"
         ;;

         "project")
            log_verbose "Cleaning project"

            shell_enable_nullglob
            for i in "${l_kitchen_dir}"/*
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
            log_verbose "Cleaning target \"${cleantarget}\""

            local directory

            craft::path::r_build_directory_name "${cleantarget}"
            directory="${RVAL}"

            if [ "${OPTION_TOUCH}" = 'NO' ]
            then
               shell_enable_nullglob
               craft::clean::remove_directories "$l_craftorder_kitchen_dir}"/*/"${directory}" \
                                                "$l_craftorder_kitchen_dir}"/*/*/"${directory}"
               shell_disable_nullglob
            fi

            local donefiles

            include "craft::donefile"

            craft::donefile::r_list_donefile_paths "${OPTION_SDK}" \
                                                   "${OPTION_PLATFORM}" \
                                                   "${OPTION_CONFIGURATION}"
            donefiles="${RVAL}"
            craft::clean::remove_item_from_donefiles "${cleantarget}" "${donefiles}"

            log_debug "Done cleaning"
         ;;
      esac

      shift
   done
}
