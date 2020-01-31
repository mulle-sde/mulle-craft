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
MULLE_CRAFT_DEPENDENCY_SH="included"


#
# The ./dependency folder is somewhat like a /usr folder, a root for
# bin share lib  folders and so on. The dependency folder is
# write protected by default.
#
# You add stuff to ./dependency by callin `dependency_begin_update`
# and when you are done you call  `dependency_end_update`. During that
# time ./dependency is not write protected.
#
# The dependency folder can be preloaded with tarball content and directory
# contents, if the environment variable DEPENDENCY_TARBALL_PATH is set
# (it contains a : separated list of tarball paths)
#
#
_dependency_install_tarballs()
{
   log_entry "_dependency_install_tarballs" "$@"

   local style="$1"

   local tarballs
   local tarball
   local tarflags

   set -f ; IFS=':'
   for tarball in ${DEPENDENCY_TARBALL_PATH}
   do
      set +f ; IFS="${DEFAULT_IFS}"

      if [ -z "${tarball}" ]
      then
         continue
      fi

      if [ ! -e "${tarball}" ]
      then
         fail "Preload \"$tarball\" not found"
      fi

      r_absolutepath "${tarball}"
      r_colon_concat "${tarballs}" "${RVAL}"
      tarballs="${RVAL}"
   done
   set +f ; IFS="${DEFAULT_IFS}"

   [ -z "${tarballs}" ] && return 0

   if [ "${MULLE_FLAG_LOG_VERBOSE}" ]
   then
      tarflags="-v"
   fi

   if [ -z "${MULLE_CRAFT_SEARCHPATH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-searchpath.sh" || exit 1
   fi

   (
      local directory

      r_get_sdk_platform_configuration_style_string "Default" \
                                              "Default" \
                                              "Release" \
                                              "${style}"
      r_filepath_concat "${DEPENDENCY_DIR}" "${RVAL}"
      directory="${RVAL}"
      mkdir_if_missing "${directory}"

      set -f ; IFS=':'
      for tarball in ${tarballs}
      do
         set +f; IFS="${DEFAULT_IFS}"

         if [ -f "${tarball}" ]
         then
            log_info "Installing tarball \"${tarball#${MULLE_USER_PWD}/}\" in \"${directory#${MULLE_USER_PWD}/}\""
            exekutor "${TAR:-tar}" -xz ${TARFLAGS} \
                                   -C "${directory}" \
                                   -f "${tarball}" || fail "failed to extract ${tar}"
         else
            log_info "Copying directory \"${tarball}\" to \"${directory#${MULLE_USER_PWD}/}\""
            (
               cd "${tarball}" &&
               exekutor "${TAR:-tar}" -cf ${TARFLAGS} .
            ) |
            (
               cd "${directory}" &&
               exekutor "${TAR:-tar}" -xf -
            ) || fail "failed to copy ${tarball}"
         fi
      done
   ) || exit 1
}


dependency_init()
{
   log_entry "dependency_init" "$@"

   local style="$1"

   [ -z "${style}" ] && internal_fail "style not set"
   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   mkdir_if_missing "${DEPENDENCY_DIR}"

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "initing"

   _dependency_install_tarballs "${style}"

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "inited"
}


dependency_unprotect()
{
   log_entry "dependency_unprotect" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ ! -e "${DEPENDENCY_DIR}" ]
   then
      return
   fi

   exekutor chmod -R ug+w "${DEPENDENCY_DIR}" || fail "could not chmod \"${DEPENDENCY_DIR}\""
}


dependency_protect()
{
   log_entry "dependency_protect" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ ! -e "${DEPENDENCY_DIR}" ]
   then
      return
   fi

   exekutor chmod -R a-w "${DEPENDENCY_DIR}" || fail "could not chmod \"${DEPENDENCY_DIR}\""
}


#
# possible states:
#
# clean
#  initing
# inited
#  updating
# ready
#
dependency_get_state()
{
   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if ! cat "${DEPENDENCY_DIR}/.state" 2> /dev/null
   then
      echo "clean"
   fi
}


dependency_get_timestamp()
{
   log_entry "dependency_get_timestamp" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ -f "${DEPENDENCY_DIR}/.state" ]
   then
      modification_timestamp "${DEPENDENCY_DIR}/.state"
   fi
}


dependency_clean()
{
   log_entry "dependency_clean" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ "${OPTION_PROTECT_DEPENDENCY}" = 'YES' ]
   then
      dependency_unprotect
      rmdir_safer "${DEPENDENCY_DIR}"
   fi
}


dependency_begin_update()
{
   log_entry "dependency_begin_update" "$@"

   local style="$1"
   local warnonrentry="${2:-nowarn}"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   local state

   state="`dependency_get_state`"
   case "${state}" in
      clean)
         dependency_init "${style}"
      ;;

      initing|initting) # previous misspell
         fail "A previous craft got stuck. Suggested remedy:
   ${C_RESET_BOLD}mulle-sde clean all"
      ;;

      inited|ready|complete)
      ;;

      updating)
         if [ "${warnonrentry}" = 'warn' ]
         then
            log_warning "dependencies: Updating an incomplete previous dependency update"
         fi
         return
      ;;

      incomplete)
         log_warning "dependencies: more projects need to be crafted successfully"
      ;;

      *)
         internal_fail "Empty or unknown dependency state \"${state}\""
      ;;

   esac


   if [ "${OPTION_PROTECT_DEPENDENCY}" = 'YES' ]
   then
      dependency_unprotect
   fi

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "updating"
}


# dont call this if your build failed, even if lenient
dependency_end_update()
{
   log_entry "dependency_end_update" "$@"

   local state="${1:-ready}"

   [ -z "${DEPENDENCY_DIR}" ] && fail "DEPENDENCY_DIR not set"

   if [ "${state}" = "complete" -a  "${OPTION_PROTECT_DEPENDENCY}" = 'YES' ]
   then
      exekutor chmod ug+wX "${DEPENDENCY_DIR}"
      exekutor chmod ug+w  "${DEPENDENCY_DIR}/.state"
   fi

   log_verbose "Dependency folder marked as ${state}"
   redirect_exekutor "${DEPENDENCY_DIR}/.state" printf "%s\n" "${state}"

   if [ "${OPTION_PROTECT_DEPENDENCY}" = 'YES' ]
   then
      dependency_protect
   fi
}


#
# Some functionality to find existing directories in the dependencies
# folder in assume order of relevance
#

r_dependency_existing_dirs_path()
{
   log_entry "r_dependency_existing_dirs_path" "$@"

   local subdirectories="$1"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   local subdir

   RVAL=""
   set -f ; IFS=$'\n'
   for subdir in ${subdirectories}
   do
      set +f ; IFS="${DEFAULT_IFS}"

      if [ -d "${DEPENDENCY_DIR}/${subdir}" ]
      then
         r_colon_concat "${RVAL}" "${DEPENDENCY_DIR}/${subdir}"
      fi
   done

   set +f; IFS="${DEFAULT_IFS}"
}


r_dependency_dir_locations()
{
   log_entry "r_dependency_dir_locations" "$@"

   local name="$1"; shift
   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ -z "${MULLE_CRAFT_SEARCHPATH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-searchpath.sh" || exit 1
   fi

   local subdir

   r_get_sdk_platform_configuration_style_string "$@"
   subdir="${RVAL}"

   r_filepath_concat "${RVAL}" "${name}"

   # kinda dodgy, why is this here ?
   #
#   case "${name}" in
#      lib|include)
#         r_add_line "${RVAL}" "usr/${name}"
#         r_add_line "${RVAL}" "usr/local/${name}"
#      ;;
#   esac
}


r_dependency_include_path()
{
   log_entry "r_dependency_include_path" "$@"

#   local sdk="$1"
#   local platform="$2"
#   local configuration="$3"

   r_dependency_dir_locations "include" "$@"
   r_dependency_existing_dirs_path "${RVAL}"
}


r_dependency_lib_path()
{
   log_entry "r_dependency_lib_path" "$@"

#   local sdk="$1"
#   local platform="$2"
#   local configuration="$3"

   r_dependency_dir_locations "lib" "$@"
   r_dependency_existing_dirs_path "${RVAL}"
}


r_dependency_frameworks_path()
{
   log_entry "r_dependency_frameworks_path" "$@"

#   local sdk="$1"
#   local platform="$2"
#   local configuration="$3"

   r_dependency_dir_locations "Frameworks" "$@"
   r_dependency_existing_dirs_path "${RVAL}"
}


r_dependency_share_path()
{
   log_entry "dependency_share_path" "$@"

#   local sdk="$1"
#   local platform="$2"
#   local configuration="$3"

   r_dependency_dir_locations "share" "$@"
   r_dependency_existing_dirs_path "${RVAL}"
}


quickstatus_main()
{
   local  state

   local OPTION_PRINT='NO'

   while :
   do
      case "$1" in
         -h*|--help|help)
            build_log_usage
         ;;

         -p|--print)
            OPTION_PRINT='YES'
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   state="`dependency_get_state`"

   log_info "${C_MAGENTA}${C_BOLD}${state}"
   if [ "${OPTION_PRINT}" = 'YES' ]
   then
      printf "%s\n" "${state}"
   fi

   if [ "${state}" = 'complete' ]
   then
      return 0
   fi
   return 4  # distinguish from error which is 1 or 2
}
