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
# bin share lib  folders and so on. The dependencies folder is
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
_dependency_install_tarballs()
{
   log_entry "_dependency_install_tarballs" "$@"

   local tarballs
   local tarball
   local tarflags

   if [ "${MULLE_FLAG_LOG_VERBOSE}" ]
   then
      tarflags="-v"
   fi

   set -f ; IFS=":"
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

      if [ -f "${tarball}" ]
      then
         log_info "Installing tarball \"${tarball}\""
         exekutor "${TAR:-tar}" -xz ${TARFLAGS} \
                                -C "${DEPENDENCY_DIR}" \
                                -f "${tarball}" || fail "failed to extract ${tar}"
      else
         log_info "Copying directory \"${tarball}\""
         (
            cd "${tarball}" &&
            exekutor "${TAR:-tar}" -cf ${TARFLAGS} .
         ) |
         (
            cd "${DEPENDENCY_DIR}" &&
            exekutor "${TAR:-tar}" -xf -
         ) || fail "failed to copy ${tarball}"
      fi

   done
   set +f; IFS="${DEFAULT_IFS}"
}


dependency_init()
{
   log_entry "dependency_init" "$@"

   local project="$1"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   mkdir_if_missing "${DEPENDENCY_DIR}"

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "initing"

   _dependency_install_tarballs

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

   local warnonrentry="${1:-nowarn}"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ "${OPTION_PROTECT_DEPENDENCY}" != 'YES' ]
   then
      return
   fi

   local state

   state="`dependency_get_state`"
   case "${state}" in
      clean)
         dependency_init
      ;;

      initing|initting) # previous misspell
         fail "A previous craft got stuck. Suggested remedy:
   ${C_RESET_BOLD}${MULLE_USAGE_NAME% *} clean dependency"
      ;;

      inited|ready)
      ;;

      updating)
         if [ "${warnonrentry}" = 'warn' ]
         then
            log_warning "dependencies: Updating an incomplete previous dependency update"
         fi
         return
      ;;

      incomplete)
         log_warning "dependencies: a previous build failed"
      ;;

      *)
         internal_fail "Empty or unknown dependency state \"${state}\""
      ;;

   esac

   dependency_unprotect

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "updating"
}


# dont call this if your build failed, even if lenient
dependency_end_update()
{
   log_entry "dependency_end_update" "$@"

   local rval=$1

   [ -z "${DEPENDENCY_DIR}" ] && fail "DEPENDENCY_DIR not set"

   if [ "${OPTION_PROTECT_DEPENDENCY}" != 'YES' ]
   then
      return
   fi

   redirect_exekutor "${DEPENDENCY_DIR}/.state" echo "ready"

   dependency_protect
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
   set -f ; IFS="
"
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

   local name="$1"
   local configuration="$2"
   local sdk="$3"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   RVAL=""
   if [ ! -z "${configuration}" ]
   then
      if [ ! -z "${sdk}" ]
      then
         r_add_line "${RVAL}" "${configuration}-${sdk}/${name}"
      fi
      r_add_line "${RVAL}" "${configuration}/${name}"
   fi
   r_add_line "${RVAL}" "${name}"

   case "${name}" in
      lib|include)
         r_add_line "${RVAL}" "usr/${name}"
         r_add_line "${RVAL}" "usr/local/${name}"
      ;;
   esac
}


r_dependency_include_path()
{
   log_entry "r_dependency_include_path" "$@"

   local configuration="$1"
   local sdk="$2"

   r_dependency_dir_locations "include" "${configuration}" "${sdk}"
   r_dependency_existing_dirs_path "${RVAL}"
}


r_dependency_lib_path()
{
   log_entry "r_dependency_lib_path" "$@"

   local configuration="$1"
   local sdk="$2"

   r_dependency_dir_locations "lib" "${configuration}" "${sdk}"
   r_dependency_existing_dirs_path "${RVAL}"
}


r_dependency_frameworks_path()
{
   log_entry "dependency_frameworks_path" "$@"

   local configuration="$1"
   local sdk="$2"

   r_dependency_dir_locations "Frameworks" "${configuration}" "${sdk}"
   r_dependency_existing_dirs_path "${RVAL}"
}


r_dependency_share_path()
{
   log_entry "dependency_share_path" "$@"

   local configuration="$1"
   local sdk="$2"

   r_dependency_dir_locations "share" "${configuration}" "${sdk}"
   r_dependency_existing_dirs_path "${RVAL}"
}



quickstatus_main()
{
   local  state

   state="`dependency_get_state`"

   log_info "Folder ${C_RESET_BOLD}${DEPENDENCY_DIR#${MULLE_USER_PWD}/}${C_INFO} is ${C_MAGENTA}${C_BOLD}${state}"

   if [ "${state}" = 'ready' ]
   then
      return 0
   fi
   return 2  # distinguish from error which is 1
}