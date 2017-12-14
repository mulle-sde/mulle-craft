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
MULLE_BUILD_DEPENDENCIES_SH="included"


#
# The ./dependencies are somewhat like a /usr folder, a root for
# bin share lib  folders and so on. The dependencies folder is
# write protected by default.
#
# You add stuff to ./dependencies by callin `dependencies_begin_update`
# and when you are done you call  `dependencies_end_update`. During that
# time ./dependencies is not write protected.
#
# The dependencies folder can be preloadeed with tarball content, if
# the environment variable TARBALLS is set (it contains a
# LF separated list of tarball paths)
#
_dependencies_install_tarballs()
{
   log_entry "_dependencies_install_tarballs" "$@"

   local tarballs
   local tarball

   IFS="
"
   for tarball in ${TARBALLS}
   do
      IFS="${DEFAULT_IFS}"

      if [ -z "${tarball}" ]
      then
         continue
      fi

      if [ ! -f "${tarball}" ]
      then
         fail "tarball \"$tarball\" not found"
      else
         mkdir_if_missing "${DEPENDENCIES_DIR}"
         log_info "Installing tarball \"${tarball}\""
         exekutor "${TAR:-tar}" -xz ${TARFLAGS} \
                                -C "${DEPENDENCIES_DIR}" \
                                -f "${tarball}" || fail "failed to extract ${tar}"
      fi
   done
   IFS="${DEFAULT_IFS}"
}


dependencies_init()
{
   log_entry "dependencies_init" "$@"

   local project="$1"

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

   mkdir_if_missing "${DEPENDENCIES_DIR}"

   redirect_exekutor "${DEPENDENCIES_DIR}/.state" \
      echo "initting"

   _dependencies_install_tarballs

   redirect_exekutor "${DEPENDENCIES_DIR}/.state" \
      echo "inited"
}


dependencies_unprotect()
{
   log_entry "dependencies_unprotect" "$@"

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

   if [ ! -e "${DEPENDENCIES_DIR}" ]
   then
      return
   fi

   chmod -R ug+w "${DEPENDENCIES_DIR}" || fail "could not chmod \"${DEPENDENCIES_DIR}\""
}


dependencies_protect()
{
   log_entry "dependencies_protect" "$@"

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

   if [ ! -e "${DEPENDENCIES_DIR}" ]
   then
      return
   fi

   chmod -R a-w "${DEPENDENCIES_DIR}" || fail "could not chmod \"${DEPENDENCIES_DIR}\""
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
   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

   if ! cat "${DEPENDENCIES_DIR}/.state" 2> /dev/null
   then
      echo "clean"
   fi
}


dependencies_get_timestamp()
{
   log_entry "dependencies_get_timestamp" "$@"

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

   if [ -f "${DEPENDENCIES_DIR}/.state" ]
   then
      modification_timestamp "${DEPENDENCIES_DIR}/.state"
   fi
}


dependencies_clean()
{
   log_entry "dependencies_clean" "$@"

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

   dependencies_unprotect
   rmdir_safer "${DEPENDENCIES_DIR}"
}


dependencies_begin_update()
{
   log_entry "dependencies_begin_update" "$@"

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

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

   redirect_exekutor "${DEPENDENCIES_DIR}/.state" \
      echo "updating"
}


dependencies_end_update()
{
   log_entry "dependencies_end_update" "$@"

   [ -z "${DEPENDENCIES_DIR}" ] && fail "DEPENDENCIES_DIR not set"

   redirect_exekutor "${DEPENDENCIES_DIR}/.state" \
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

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

   local subdir
   local path

   IFS="
"
   for subdir in ${subdirectories}
   do
      IFS="${DEFAULT_IFS}"

      if [ -d "${DEPENDENCIES_DIR}/${subdir}" ]
      then
         path="`colon_concat "${path}" "${DEPENDENCIES_DIR}/${subdir}"`"
      fi
   done

   IFS="${DEFAULT_IFS}"

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

   [ -z "${DEPENDENCIES_DIR}" ] && internal_fail "DEPENDENCIES_DIR not set"

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

