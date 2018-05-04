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
MULLE_CRAFT_DEPENDENCIES_SH="included"


#
# The ./dependency folder is somewhat like a /usr folder, a root for
# bin share lib  folders and so on. The dependencies folder is
# write protected by default.
#
# You add stuff to ./dependency by callin `dependencies_begin_update`
# and when you are done you call  `dependencies_end_update`. During that
# time ./dependency is not write protected.
#
# The dependency folder can be preloaded with tarball content and directory
# contents, if the environment variable MULLE_CRAFT_DEPENDENCY_PRELOADS is set
# (it contains a : separated list of tarball paths)
#
_dependencies_install_tarballs()
{
   log_entry "_dependencies_install_tarballs" "$@"

   local tarballs
   local tarball
   local tarflags

   if [ "${MULLE_FLAG_LOG_VERBOSE}" ]
   then
      tarflags="-v"
   fi

   set -f ; IFS=":"
   for tarball in ${MULLE_CRAFT_DEPENDENCY_PRELOADS}
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


dependencies_init()
{
   log_entry "dependencies_init" "$@"

   local project="$1"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   mkdir_if_missing "${DEPENDENCY_DIR}"

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "initting"

   _dependencies_install_tarballs

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "inited"
}


dependencies_unprotect()
{
   log_entry "dependencies_unprotect" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ ! -e "${DEPENDENCY_DIR}" ]
   then
      return
   fi

   chmod -R ug+w "${DEPENDENCY_DIR}" || fail "could not chmod \"${DEPENDENCY_DIR}\""
}


dependencies_protect()
{
   log_entry "dependencies_protect" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ ! -e "${DEPENDENCY_DIR}" ]
   then
      return
   fi

   chmod -R a-w "${DEPENDENCY_DIR}" || fail "could not chmod \"${DEPENDENCY_DIR}\""
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
dependencies_get_state()
{
   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if ! cat "${DEPENDENCY_DIR}/.state" 2> /dev/null
   then
      echo "clean"
   fi
}


dependencies_get_timestamp()
{
   log_entry "dependencies_get_timestamp" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ -f "${DEPENDENCY_DIR}/.state" ]
   then
      modification_timestamp "${DEPENDENCY_DIR}/.state"
   fi
}


dependencies_clean()
{
   log_entry "dependencies_clean" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   dependencies_unprotect
   rmdir_safer "${DEPENDENCY_DIR}"
}


dependencies_begin_update()
{
   log_entry "dependencies_begin_update" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   local state

   state="`dependencies_get_state`"
   case "${state}" in
      clean)
         dependencies_init
      ;;

      initing)
         fail "A previous init got stuck. Clean and try again (maybe)"
      ;;

      inited|ready)
      ;;

      updating)
         log_warning "dependencies: Updating an incomplete previous update"
      ;;

      ""|*)
         internal_fail "Empty or unknown state \"${state}\""
      ;;

   esac

   dependencies_unprotect

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "updating"
}


dependencies_end_update()
{
   log_entry "dependencies_end_update" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && fail "DEPENDENCY_DIR not set"

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      echo "ready"

   dependencies_protect
}


#
# Some functionality to find existing directories in the dependencies
# folder in assume order of relevance
#

dependencies_existing_dirs_path()
{
   log_entry "dependencies_existing_dirs_path" "$@"

   local subdirectories="$1"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   local subdir
   local path

   set -f ; IFS="
"
   for subdir in ${subdirectories}
   do
      set +f ; IFS="${DEFAULT_IFS}"

      if [ -d "${DEPENDENCY_DIR}/${subdir}" ]
      then
         path="`colon_concat "${path}" "${DEPENDENCY_DIR}/${subdir}"`"
      fi
   done

   set +f; IFS="${DEFAULT_IFS}"

   if [ ! -z "${path}" ]
   then
      echo "${path}"
   fi
}


dependencies_dir_locations()
{
   log_entry "dependencies_dir_locations" "$@"

   local name="$1"
   local configuration="$2"
   local sdk="$3"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ ! -z "${configuration}" ]
   then
      if [ ! -z "${sdk}" ]
      then
         echo "${configuration}-${sdk}/${name}"
      fi
      echo "${configuration}/${name}"
   fi
   echo "${name}"
   case "${name}" in
      lib|include)
         echo "usr/${name}
usr/local/${name}"
      ;;
   esac
}


dependencies_include_path()
{
   log_entry "dependencies_include_path" "$@"

   local configuration="$1"
   local sdk="$2"

   local subdirectories

   subdirectories="`dependencies_dir_locations "include" \
                                               "${configuration}" \
                                               "${sdk}"`"
   dependencies_existing_dirs_path "${subdirectories}"
}


dependencies_lib_path()
{
   log_entry "dependencies_lib_path" "$@"

   local configuration="$1"
   local sdk="$2"

   local subdirectories

   subdirectories="`dependencies_dir_locations "lib" \
                                               "${configuration}" \
                                               "${sdk}"`"
   dependencies_existing_dirs_path "${subdirectories}"
}


dependencies_frameworks_path()
{
   log_entry "dependencies_frameworks_path" "$@"

   local configuration="$1"
   local sdk="$2"

   local subdirectories

   subdirectories="`dependencies_dir_locations "Frameworks" \
                                               "${configuration}" \
                                               "${sdk}"`"
   dependencies_existing_dirs_path "${subdirectories}"
}


dependencies_share_path()
{
   log_entry "dependencies_share_path" "$@"

   local configuration="$1"
   local sdk="$2"

   local subdirectories

   subdirectories="`dependencies_dir_locations "share" \
                                               "${configuration}" \
                                               "${sdk}"`"
   dependencies_existing_dirs_path "${subdirectories}"
}

