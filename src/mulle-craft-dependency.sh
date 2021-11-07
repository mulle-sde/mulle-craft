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


craft_install_tarball()
{
   local tarball="$1"
   local dst_dir="$2"

   log_info "Installing tarball \"${tarball#${MULLE_USER_PWD}/}\" in \"${dst_dir#${MULLE_USER_PWD}/}\""
   exekutor "${TAR:-tar}" -xz ${TARFLAGS} \
                          -C "${dst_dir}" \
                          -f "${tarball}" || fail "failed to extract ${tar}"
}


craft_install_directory()
{
   local src_dir="$1"
   local dst_dir="$2"

   log_info "Copying directory \"${src_dir#${MULLE_USER_PWD}/}\" to \"${dst_dir#${MULLE_USER_PWD}/}\""
   (
      cd "${src_dir}" &&
      exekutor "${TAR:-tar}" -cf ${TARFLAGS} .
   ) |
   (
      cd "${dst_dir}" &&
      exekutor "${TAR:-tar}" -xf -
   ) || fail "failed to copy ${src_dir}"
}

#
# The ./dependency folder is somewhat like a /usr folder, a root for
# bin share lib  folders and so on. The dependency folder is
# write protected by default.
#
# You add stuff to ./dependency by calling `dependency_begin_update`
# and when you are done you call  `dependency_end_update`. During that
# time ./dependency is not write protected.
#
# The dependency folder can be preloaded with tarball content and directory
# contents, if the environment variable DEPENDENCY_TARBALLS is set
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

   # DEPENDENCY_TARBALL_PATH is the old name, fallen out of favor
   shell_disable_glob ; IFS=':'
   for tarball in ${TARBALLS:-${DEPENDENCY_TARBALL_PATH}}
   do
      shell_enable_glob; IFS="${DEFAULT_IFS}"

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
   shell_enable_glob; IFS="${DEFAULT_IFS}"

   [ -z "${tarballs}" ] && return 0

   if [ "${MULLE_FLAG_LOG_VERBOSE}" ]
   then
      tarflags="-v"
   fi

   if [ -z "${MULLE_CRAFT_STYLE_SH}" ]
   then
      # shellcheck source=src/mulle-craft-style.sh
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-style.sh" || exit 1
   fi


   (
      local directory

      r_get_sdk_platform_configuration_style_string "Default" \
                                                    "${MULLE_UNAME}" \
                                                    "Release" \
                                                    "${style}"

      r_filepath_concat "${DEPENDENCY_DIR}" "${RVAL}"
      directory="${RVAL}"

      shell_disable_glob ; IFS=':'
      for tarball in ${tarballs}
      do
         shell_enable_glob; IFS="${DEFAULT_IFS}"

         local dst_dir

         dst_dir="${directory}"

         # little hack for convenience..
         case "${tarball}" in 
            *\.[Ff][Rr][Aa][Mm][Ee][Ww][Oo][Rr][Kk]\.*|*\.[Ff][Rr][Aa][Mm][Ee][Ww][Oo][Rr][Kk][Ss].*)
               r_filepath_concat "${directory}" "Frameworks"
               dst_dir="${RVAL}"
            ;;
         esac

         mkdir_if_missing "${dst_dir}"

         if [ -f "${tarball}" ]
         then
            craft_install_tarball "${tarball}" "${dst_dir}"
         else
            craft_install_directory "${tarball}" "${dst_dir}"
         fi
      done
   ) || exit 1
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

   if ! rexekutor egrep -v '^#' "${DEPENDENCY_DIR}/.state" 2> /dev/null
   then
      echo "clean"
   fi
}

#
# Optimally:
#    clean -> initing -> inited -> ready -> complete
#
dependency_set_state()
{
   local state="$1"

   log_verbose "Dependency folder marked as ${state}"

   redirect_exekutor "${DEPENDENCY_DIR}/.state" \
      printf "%s\n" "${state}"

   local script 

   # run some callbacks on specified states
   case "${state}" in 
      inited|complete)
         if [ -z "${MULLE_CRAFT_ETC_DIR}" ]
         then
            eval `"${MULLE_ENV:-mulle-env}" --search-as-is mulle-tool-env craft`
         fi         

         #
         # Memo: there can be breakage on a mulle-sde upgrade, if in share a .darwin
         #       pops up, which wasn't already there. Solution, don't do this!
         #
         script="${MULLE_CRAFT_ETC_DIR}/callback-${state}.${MULLE_UNAME}"
         if [ ! -f "${script}" ]
         then
            script="${MULLE_CRAFT_SHARE_DIR}/callback-${state}.${MULLE_UNAME}"
            if [ ! -f "${script}" ]
            then
               script="${MULLE_CRAFT_ETC_DIR}/callback-${state}"
               if [ ! -f "${script}" ]
               then
                  script="${MULLE_CRAFT_SHARE_DIR}/callback-${state}"
                  if [ ! -f "${script}" ]
                  then
                     script=""
                  fi
               fi
            fi
         fi

         if [ ! -z "${script}" ]
         then
            if [ ! -x "${script}" ]
            then
               fail "Script \"${script#${MULLE_USER_PWD}/}\" is not executable"
            fi
            log_info "Executing \"${script#${MULLE_USER_PWD}/}\""

            DEPENDENCY_DIR="${DEPENDENCY_DIR}"
               exekutor "${script}" "${state}" || exit 1
         fi
      ;;
   esac
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


dependency_init()
{
   log_entry "dependency_init" "$@"

   local style="$1"

   [ -z "${style}" ] && internal_fail "style not set"
   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   mkdir_if_missing "${DEPENDENCY_DIR}"

   dependency_set_state "initing"

   _dependency_install_tarballs "${style}"

   dependency_set_state "inited"
}


dependency_unprotect()
{
   log_entry "dependency_unprotect" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ ! -d "${DEPENDENCY_DIR}" ]
   then
      return
   fi

   log_fluff "Unprotecting ${DEPENDENCY_DIR#${MULLE_USER_PWD}/}"
   exekutor chmod -R ug+w "${DEPENDENCY_DIR}" || fail "could not chmod \"${DEPENDENCY_DIR}\""
}


dependency_protect()
{
   log_entry "dependency_protect" "$@"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   if [ ! -d "${DEPENDENCY_DIR}" ]
   then
      return
   fi

   log_fluff "Protecting ${DEPENDENCY_DIR#${MULLE_USER_PWD}/}"
   exekutor chmod -R a-w "${DEPENDENCY_DIR}" || fail "could not chmod \"${DEPENDENCY_DIR}\""
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


#
# style is pushed through for tarball install
#
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
         # still want to unprotect, changing state again to updating is harmless
      ;;

      incomplete)
         log_warning "dependencies: more projects need to be crafted successfully"
      ;;

      *)
         internal_fail "Empty or unknown dependency state \"${state}\""
      ;;
   esac

   log_fluff "Dependency update started"

   if [ "${OPTION_PROTECT_DEPENDENCY}" = 'YES' ]
   then
      dependency_unprotect
   fi

   dependency_set_state "updating"
}


#
# dont call this if your build failed, even if lenient
# "complete" is the final state
#
dependency_end_update()
{
   log_entry "dependency_end_update" "$@"

   local state="${1:-ready}"

   [ -z "${DEPENDENCY_DIR}" ] && internal_fail "DEPENDENCY_DIR not set"

   log_fluff "Dependency update ended with ${state}"

   if [ "${state}" = "complete" ]
   then
      if [ "${OPTION_PROTECT_DEPENDENCY}" = 'YES' ]
      then
         exekutor chmod ug+wX "${DEPENDENCY_DIR}"
         exekutor chmod ug+w  "${DEPENDENCY_DIR}/.state"
      fi

      dependency_set_state "${state}"

      if [ "${OPTION_PROTECT_DEPENDENCY}" = 'YES' ]
      then
         dependency_protect
      fi
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
   shell_disable_glob; IFS=$'\n'
   for subdir in ${subdirectories}
   do
      shell_enable_glob; IFS="${DEFAULT_IFS}"

      if [ -d "${DEPENDENCY_DIR}/${subdir}" ]
      then
         r_colon_concat "${RVAL}" "${DEPENDENCY_DIR}/${subdir}"
      fi
   done

   shell_enable_glob; IFS="${DEFAULT_IFS}"
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

   if [ -z "${MULLE_CRAFT_STYLE_SH}" ]
   then
      # shellcheck source=src/mulle-craft-style.sh
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-style.sh" || exit 1
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
   return 2  # distinguish from error which is 1
}
