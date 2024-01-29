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
MULLE_CRAFT_CRAFTINFO_SH='included'



craft::craftinfo::usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} find [options] [dependency]

   Search for a craftinfo item in a project or in a dependency project.
   The item can either be a file or a directory. Dependency projects
   craftinfo can be overridden by craftinfos in dependency/share/mulle-craft.

Options:
   --project-dir <dir>    : project directory (\$PWD)
   --dependency-dir <dir> : dependency directory (dependency)
   --item <name>          : search for file or directory (definition)
   --no-platform          : ignore platform specific craftinfo
   --no-local             : ignore local .mulle/etc/craft craftinfo

Environment:
   DEPENDENCY_DIR         : default dependency dir
EOF
  exit 1
}


#
# basically expands searchpath with "${directory}/definition" to
# ${directory}/definition.linux:${directory}/definiton"
# and now to
# ${directory}/definition.musl.linux:${directory}/definition.linux:{directory}/definiton.musl.ALL:${directory}/definiton"

craft::craftinfo::r_find_item()
{
   log_entry "craft::craftinfo::r_find_item" "$@"

   local directory="$1"
   local sdk="$2"
   local platform="$3"
   local allowplatform="$4"
   local itemname="$5"

   [ -z "${directory}" ] && _internal_fail "empty directory"
   [ -z "${itemname}" ]  && _internal_fail "empty itemname"
   [ -z "${sdk}" ]       && _internal_fail "empty SDK"

   if [ "${allowplatform}" != 'NO' ]   # empty is OK
   then
      [ -z "${platform}" ] && _internal_fail "empty platform"

      if [ "${platform}" = 'Default' ]
      then
         platform="${MULLE_UNAME}"
      fi

      if [ "${sdk}" != 'Default' ]
      then
         RVAL="${directory}/${itemname}.${sdk}.${platform}"
         if rexekutor [ -e "${RVAL}" ]
         then
            log_fluff "\"${RVAL#"${MULLE_USER_PWD}/"}\" found"
            return
         fi
      else
         RVAL="${directory}/${itemname}.${platform}"
         if rexekutor [ -e "${RVAL}" ]
         then
            log_fluff "\"${RVAL#"${MULLE_USER_PWD}/"}\" found"
            return
         fi
      fi
   fi

   if [ "${sdk}" != 'Default' ]
   then
      RVAL="${directory}/${itemname}.${sdk}.ALL"
      if rexekutor [ -e "${RVAL}" ]
      then
         log_fluff "\"${RVAL#"${MULLE_USER_PWD}/"}\" found"
         return
      fi
   fi

   RVAL="${directory}/${itemname}"
   if rexekutor [ -e "${RVAL}" ]
   then
      log_fluff "\"${RVAL#"${MULLE_USER_PWD}/"}\" found"
      return
   fi

   RVAL=""
   return 2
}


#
# find the dependency/share/mulle-craft/<projectname> folder
# which is dependent on style/configuration (already encoded in subdir)
#
craft::craftinfo::r_find_dependency_dir()
{
   log_entry "craft::craftinfo::r_find_dependency_dir" "$@"

   [ $# -eq 6 ] || _internal_fail "api error"

   local projectname="$1"   # can be empty now for "root"
   local dependencydir="${2:-dependency}"
   local sdk="${3:-Default}"
   local platform="${4:-Default}"
   local configuration="${5:-Release}"
   local style="${6:-none}"

   local subdir

   include "craft::style"

   craft::style::r_get_sdk_platform_configuration_string "${sdk}" \
                                                         "${platform}" \
                                                         "${configuration}" \
                                                         "${style}"
   subdir="${RVAL}"
   log_debug  "subdir : ${subdir}"

   local pathitem

   .foreachpath pathitem in ${CRAFTINFO_PATH}
   .do
      r_filepath_concat "${pathitem}" "${projectname}"
      if rexekutor [ -d "${RVAL}" ]
      then
         return 0
      fi
   .done

   if [ ! -z "${subdir}" ]
   then
      local depsubdir

      r_filepath_concat "${dependencydir}" "${subdir}"
      depsubdir="${RVAL}"

      log_debug  "depsubdir : ${depsubdir}"


      r_filepath_concat "${depsubdir}" "share" "mulle-craft" "${projectname}"
      if rexekutor [ -d "${RVAL}" ]
      then
         return 0
      fi
   fi

   log_debug  "dependencydir : ${dependencydir}"

   # fallback on default
   r_filepath_concat "${dependencydir}" "share" "mulle-craft" "${projectname}"
   if rexekutor [ -d "${RVAL}" ]
   then
      return 0
   fi

   RVAL=""
   return 2
}


craft::craftinfo::r_find_dependency_item()
{
   log_entry "craft::craftinfo::r_find_dependency_item" "$@"

   #
   # upper case for the sake of sameness for ppl setting MULLE_CRAFT_CRAFTINFO_PATH
   # in the environment ?=??
   #
   [ $# -eq 7 ] || _internal_fail "api error"

   local name="$1"
   local allowplatform="${2:-YES}"
   local sdk="${3:-Default}"
   local platform="${4:-Default}"
   local configuration="${5:-Release}"
   local style="${6:-none}"
   local itemname="${7:-definition}"

   # -z name is actually normal!

   # projectname
   local projectname

   r_basename "${name}"
   projectname="${RVAL}"

   # this is OK it's then a "root" definition
   # [ -z "${projectname}" ] && _internal_fail "${name} is empty"

   local rval

   craft::craftinfo::r_find_dependency_dir "${projectname}" \
                                           "${DEPENDENCY_DIR}" \
                                           "${sdk}" \
                                           "${platform}" \
                                           "${configuration}" \
                                           "${style}"
   rval=$?
   if [ $rval -ne 0 ]
   then
      log_debug "No ${itemname} for \"${projectname}\" in \"${DEPENDENCY_DIR}\" found"
      return $rval
   fi

   directory="${RVAL}"

   if craft::craftinfo::r_find_item "${directory}" \
                                    "${sdk}" \
                                    "${platform}" \
                                    "${allowplatform}" \
                                    "${itemname}"
   then
      return 0
   fi

   log_debug "No ${itemname} for \"${projectname}\" in \"${directory}\" found"
   RVAL=""
   return 2
}


craft::craftinfo::r_project_dir()
{
   log_entry "craft::craftinfo::r_project_dir" "$@"

   [ $# -eq 1 ] || _internal_fail "api error"

   local projectdir="${1:-${PWD}}"

   RVAL="${projectdir}/.mulle/etc/craft"
   if [ ! -d "${RVAL}" ]
   then
      RVAL="${projectdir}/.mulle/share/craft"
      if [ ! -d "${RVAL}" ]
      then
         RVAL=""
         return 2
      fi
   fi

   return 0
}


craft::craftinfo::r_find_project_item()
{
   log_entry "craft::craftinfo::r_find_project_item" "$@"

   local name="${1:-unknown}"
   local projectdir="${2:-${PWD}}"
   local allowplatform="${3:-YES}"
   local sdk="${4:-Default}"
   local platform="${5:-Default}"
   local itemname="${6:-definition}"

   local directory

   if craft::craftinfo::r_project_dir "${projectdir}"
   then
      directory="${RVAL}"

      if craft::craftinfo::r_find_item "${directory}" \
                                       "${sdk}" \
                                       "${platform}" \
                                       "${allowplatform}" \
                                       "${itemname}"
      then
         return 0
      fi
   fi

   log_debug "No ${itemname} for \"${name}\" in project found"

   RVAL=""
   return 2
}


craft::craftinfo::main()
{
   log_entry "craft::craftinfo::main" "$@"

   local OPTION_PROJECT_DIR
   local OPTION_PLATFORM_CRAFTINFO="${MULLE_CRAFT_PLATFORM_CRAFTINFO:-YES}"
   local OPTION_LOCAL_CRAFTINFO="${MULLE_CRAFT_LOCAL_CRAFTINFO:-YES}"
   local OPTION_PLATFORM='Default'
   local OPTION_SDK='Default'
   local OPTION_CONFIGURATION='Release'
   local OPTION_STYLE='auto'
   local OPTION_ITEM="definition"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft::craftinfo::usage
         ;;

         -d|--project-dir)
            [ $# -eq 1 ] && craft::craftinfo::usage "Missing argument to \"$1\""
            shift

            OPTION_PROJECT_DIR="$1"  # could be global env
         ;;

         --dependency-dir)
            [ $# -eq 1 ] && craft::craftinfo::usage "Missing argument to \"$1\""
            shift

            DEPENDENCY_DIR="$1"  # could be global env
         ;;

         --no-platform|--no-platform-craftinfo)
            OPTION_PLATFORM_CRAFTINFO='NO'
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL_CRAFTINFO='NO'
         ;;

         --item)
            [ $# -eq 1 ] && craft::craftinfo::craftinfo_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_ITEM="$1"
         ;;

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft::craftinfo::craftinfo_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft::craftinfo::craftinfo_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft::craftinfo::craftinfo_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         --style)
            [ $# -eq 1 ] && craft::craftinfo::craftinfo_searchpath_usage "Missing argument to \"$1\""
            shift

            OPTION_STYLE="$1"
         ;;


         -*)
            craft::craftinfo::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local name="$1"

   [ $# -ne 0 ] && shift
   [ $# -eq 0 ] || craft::style::usage "Superflous arguments \"$*\""

   if [ -z "${name}" ]
   then
      OPTION_PROJECT_DIR="${OPTION_PROJECT_DIR:-${PWD}}"
      r_basename "${OPTION_PROJECT_DIR}"
      name="${RVAL}"
   else
      r_basename "${name}"
      OPTION_PROJECT_DIR="${OPTION_PROJECT_DIR:-${MULLE_SOURCETREE_STASH_DIRNAME:-stash}/${RVAL}}"
   fi

   if craft::craftinfo::r_find_dependency_item "${name}" \
                                               "${OPTION_PLATFORM_CRAFTINFO}" \
                                               "${OPTION_SDK}" \
                                               "${OPTION_PLATFORM}" \
                                               "${OPTION_CONFIGURATION}" \
                                               "${OPTION_STYLE}" \
                                               "${OPTION_ITEM}"
   then
      printf "%s\n" "${RVAL}"
      return
   fi

   if [ "${OPTION_LOCAL_CRAFTINFO}" = 'NO' ]
   then
      return 2
   fi

   local rval

   craft::craftinfo::r_find_project_item "${name}" \
                                         "${OPTION_PROJECT_DIR}" \
                                         "${OPTION_PLATFORM_CRAFTINFO}" \
                                         "${OPTION_SDK}" \
                                         "${OPTION_PLATFORM}" \
                                         "${OPTION_ITEM}"
   rval=$?

   [ $rval -eq 0 ] && printf "%s\n" "${RVAL}"

   return $rval
}

