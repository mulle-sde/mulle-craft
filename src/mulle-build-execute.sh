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
MULLE_BUILD_EXECUTE_SH="included"


build_execute_usage()
{
    cat <<EOF >&2
Usage:
   ${MULLE_EXECUTABLE_NAME} execute [options]

   Build the current project or sourcetree.

Options:
   ...

Environment:
   MULLE_BUILD_INFO_DIR  : place to find .mulle-buildinfo (fallback, optional)
   DEPENDENCIES_DIR     : place to put dependencies (usually required)
   ADDICTIONS_DIR       : place to get addictions from (optional)
EOF
  exit 1
}


#
# What build does is call
#


#
# if only one configuration is chosen, make it the default
# if there are multiple configurations, make Release the default
# if Release is not in multiple configurations, then there is no default
#
determine_build_subdir()
{
   log_entry "determine_build_subdir" "$@"

   local configuration="$1"
   local sdk="$2"

   [ -z "$configuration" ] && internal_fail "configuration must not be empty"
   [ -z "$sdk" ]           && internal_fail "sdk must not be empty"

   sdk=`echo "${sdk}" | "${SED:-sed}" 's/^\([a-zA-Z]*\).*$/\1/g'`

   if [ "${sdk}" = "Default" ]
   then
      if [ "${configuration}" != "Release" ]
      then
         echo "/${configuration}"
      fi
   else
      echo "/${configuration}-${sdk}"
   fi
}


determine_dependencies_subdir()
{
   log_entry "determine_dependencies_subdir" "$@"

   local configuration="$1"
   local sdk="$2"
   local style="$3"

   [ -z "${configuration}" ] && internal_fail "configuration must not be empty"
   [ -z "${sdk}" ]           && internal_fail "sdk must not be empty"
   [ -z "${SDKS}" ]          && internal_fail "SDKS must not be empty"

   sdk=`echo "${sdk}" | "${SED}" 's/^\([a-zA-Z]*\).*$/\1/g'`

   if [ "${style}" = "auto" ]
   then
      style="configuration"

      n_sdks="`echo "${SDKS}" | wc -l | awk '{ print $1 }'`"
      if [ $n_sdks -gt 1 ]
      then
         style="configuration-sdk"
      fi
   fi

   case "${style}" in
      "none")
      ;;

      "configuration-strict")
         echo "/${configuration}"
      ;;

      "configuration-sdk-strict")
         echo "/${configuration}-${sdk}"
      ;;

      "configuration-sdk")
         if [ "${sdk}" = "Default" ]
         then
            if [ "${configuration}" != "Release" ]
            then
               echo "/${configuration}"
            fi
         else
            echo "/${configuration}-${sdk}"
         fi
      ;;

      "configuration")
         if [ "${configuration}" != "Release" ]
         then
            echo "/${configuration}"
         fi
      ;;

      *)
         fail "unknown value \"${style}\" for dispense style"
      ;;
   esac
}


determine_buildinfo_dir()
{
   log_entry "determine_buildinfo_dir" "$@"

   local name="$1"
   local projectdir="$2"

   local buildinfodir

   buildinfodir="${OPTION_INFO_DIR}"
   if [ -z "${buildinfodir}" ] && [ ! -d "${buildinfodir}" ]
   then
      buildinfodir="${DEPENDENCIES_DIR}/share/mulle-build/${name}.${UNAME}"
      if [ ! -d "${buildinfodir}" ]
      then
         buildinfodir="${DEPENDENCIES_DIR}/share/mulle-build/${name}"
         if [ ! -d "${buildinfodir}" ]
         then
            buildinfodir="${projectdir}/.mulle-build.${UNAME}"
            if [ ! -d "${buildinfodir}" ]
            then
               buildinfodir="${projectdir}/.mulle-build"
               if [ ! -d "${buildinfodir}" ]
               then
                  buildinfodir="${MULLE_BUILD_INFO_DIR}/${name}.${UNAME}"
                  if [ ! -d "${buildinfodir}" ]
                  then
                     buildinfodir="${MULLE_BUILD_INFO_DIR}/${name}"
                     if [ ! -d "${buildinfodir}" ]
                     then
                        return 1
                     fi
                  fi
               fi
            fi
         fi
      fi
   fi
   echo "${buildinfodir}"
}


build_project()
{
   log_entry "build_project" "$@"

   local project="$1"
   local cmd="$2"
   local destination="$3"
   local configuration="$4"
   local sdk="$5"

   local includepath
   local frameworkspath
   local libpath

   if [ ! -z "${DEPENDENCIES_DIR}" ]
   then
      includepath="`dependencies_include_path "${configuration}" "${sdk}"`"
      libpath="`dependencies_lib_path "${configuration}" "${sdk}"`"
      case "${UNAME}" in
         darwin)
            frameworkspath="`dependencies_frameworks_path "${configuration}" "${sdk}"`"
         ;;
      esac
   fi

   if [ ! -z "${ADDICTIONS_DIR}" ]
   then
      if [ -d "${ADDICTIONS_DIR}/include" ]
      then
         includepath="`add_path "${includepath}" "${ADDICTIONS_DIR}/include"`"
      fi

      if [ -d "${ADDICTIONS_DIR}/lib" ]
      then
         libpath="`add_path "${libpath}" "${ADDICTIONS_DIR}/lib"`"
      fi
   fi

   #
   # locate proper buildinfo path
   # searchpath:
   #
   # dependencies/share/mulle-buildinfo/<name>.txt
   # <project>/.mulle-buildinfo
   # ${MULLE_BUILD_INFO_DIR}/<name>.txt
   #
   local name
   local buildinfodir

   name="`extensionless_basename "${project}"`"
   buildinfodir="`determine_buildinfo_dir "${name}" "${project}"`"

   #
   # find proper build directory
   #
   local builddir

   builddir="${MULLE_BUILD_DIR:-build}"

   #
   # find proper log directory
   #
   local logdir

   logdir="${builddir/.logs}"

   #
   # call mulle-make with all we've got now
   #
   local args

   args="${OPTIONS_MULLE_MAKE}"

   if [ ! -z "${logdir}" ]
   then
      args="`concat "${args}" "--log-dir '${logdir}'" `"
   fi
   if [ ! -z "${builddir}" ]
   then
      args="`concat "${args}" "--build-dir '${builddir}'" `"
   fi
   if [ ! -z "${buildinfodir}" ]
   then
      args="`concat "${args}" "--info-dir '${buildinfodir}'" `"
   fi
   if [ ! -z "${configuration}" ]
   then
      args="`concat "${args}" "--configuration '${configuration}'" `"
   fi
   if [ ! -z "${sdk}" ]
   then
      args="`concat "${args}" "--sdk '${sdk}'" `"
   fi
   if [ ! -z "${includepath}" ]
   then
      args="`concat "${args}" "--include-path '${includepath}'" `"
   fi
   if [ ! -z "${libpath}" ]
   then
      args="`concat "${args}" "--lib-path '${libpath}'" `"
   fi
   if [ ! -z "${frameworkspath}" ]
   then
      args="`concat "${args}" "--frameworks-path '${frameworkspath}'" `"
   fi

   eval_exekutor "'${MULLE_MAKE}'" "${cmd}" "${args}"
}


build_dependency_directly()
{
   log_entry "build_dependency_directly" "$@"

   local project="$1"

   dependencies_begin_update || return 1

   #
   # build first configuration and sdk only
   #
   local configuration
   local sdk

   IFS=","
   for configuration in ${CONFIGURATIONS}
   do
      IFS=","
      for sdk in ${SDKS}
      do
         IFS="${DEFAULT_IFS}"

         build_project "${project}" \
                       "install" \
                       "${DEPENDENCIES_DIR}" \
                       "${configuration}" \
                       "${sdk}"
         return $?
      done
   done
   IFS="${DEFAULT_IFS}"

   dependencies_end_update || return 1

}


build_dependency_with_dispense()
{
   log_entry "build_dependency_with_dispense" "$@"

   local project="$1"

   IFS=","
   for configuration in ${CONFIGURATIONS}
   do
      IFS=","
      for sdk in ${SDKS}
      do
         IFS="${DEFAULT_IFS}"

         local subdir

         subdir="`determine_dependencies_subdir "${configuration}" \
                                                "${sdk}" \
                                                "${DISPENSE_STYLE}"`"

         rmdir_safer "${DEPENDENCIES_DIR}.tmp" || return 1

         build_project "${project}" \
                       "install" \
                       "${DEPENDENCIES_DIR}.tmp" \
                       "${configuration}" \
                       "${sdk}"

         dependencies_begin_update &&
         "${MULLE_DISPENSE}" "${DEPENDENCIES_DIR}.tmp" "${DEPENDENCIES_DIR}${subdir}"  &&
         dependencies_end_update

         if [ $? -ne 0 -a "${OPTION_LENIENT}" = "NO" ]
         then
            return 1
         fi
      done
   done
   IFS="${DEFAULT_IFS}"
}


build_dependency()
{
   log_entry "build_dependency" "$@"

   local project="$1"
   local marks="$2"

   case "${marks}" in
      *nodispense*)
         build_dependency_directly "${project}"
      ;;

      *)
         build_dependency_with_dispense "${project}"
      ;;
   esac

   return 0
}


#
# non-dependencies are build with their own BUILD_DIR
# not in the shared one.
#
build_with_buildorder()
{
   log_entry "build_with_buildorder" "$@"

   local buildorder="$1"
   local style="$2"
   local cmd="$3"
   local functionname="$4"
   local builddir="$5"
   local donefile="$6"

   local remaining

   [ ! -z "${builddir}" ] || internal_fail "builddir is empty"

   mkdir_if_missing "${builddir}" || fail "Could not create build directory"

   remaining="${buildorder}"
   if [ ! -z "${donefile}" ]
   then
      if [ -f "${donefile}" ]
      then
         remaining="`fgrep -x -v -f "${donefile}" <<< "${buildorder}"`"
         if [ -z "${remaining}" ]
         then
            log_verbose "Everything has been built already"
            return
         fi
      fi
   fi

   [ ! -z "${CONFIGURATIONS}" ] || internal_fail "CONFIGURATIONS is empty"
   [ ! -z "${SDKS}" ]           || internal_fail "SDKS is empty"

   local line

   IFS="
"
   for line in ${remaining}
   do
      IFS="${DEFAULT_IFS}"

      local project
      local marks

      IFS=";" read project marks <<< "${line}"

      if [ -z "${project}" ]
      then
         internal_fail "empty project fail"
      fi

      case "${style}" in
         dependencies)
            case "${marks}" in
               *nodependency*)
                  log_fluff "\"${project}\" marked as nodependency, ignore"
                  continue
               ;;
            esac
         ;;

         *)
            case "${marks}" in
               *nodependency*)
                  # ok!
               ;;

               ""|*)
                  log_fluff "\"${project}\" marked as dependency, ignore"
                  continue
               ;;
            esac
         ;;
      esac

      log_fluff "Build \"${project}\""

      (
         BUILD_DIR="${builddir}" "${functionname}" "${project}" "${cmd}" "${marks}"
      )

      if [ $? -eq 0 ]
      then
         if [ ! -z "${donefile}" ]
         then
            redirect_append_exekutor "${donefile}" echo "${line}"
         fi
      else
         if [ "${OPTION_LENIENT}" = "NO" ]
         then
            log_fluff "Build of \"${project}\" failed, so quite"
            return 1
         fi
         log_fluff "Ignore failure of \"${project}\" due to leniency option"
      fi
   done
   IFS="${DEFAULT_IFS}"
}


do_build_sourcetree()
{
   log_entry "do_build_sourcetree" "$@"

   [ -z "${MULLE_BUILD_DEPENDENCIES_SH}" ] && . "${MULLE_BUILD_LIBEXEC_DIR}/mulle-build-dependencies.sh"

   if ! exekutor "${MULLE_SOURCETREE}" ${MULLE_SOURCETREE_FLAGS} status --is-uptodate
   then
      eval_exekutor "'${MULLE_SOURCETREE}'" "${MULLE_SOURCETREE_FLAGS}" "${OPTION_MODE}" "update"  || exit 1
   fi

   local buildorder
   local builddir

   buildorder="`"${MULLE_SOURCETREE}" ${MULLE_SOURCETREE_FLAGS} buildorder --marks`" || exit 1
   if [ -z "${buildorder}" ]
   then
      log_verbose "Nothing to build according to ${MULLE_SOURCETREE}"
      return
   fi

   if [ ! -z "${DEPENDENCIES_DIR}" ]
   then
      log_verbose "Building dependencies..."

      builddir="${OPTION_DEPENDENCIES_BUILD_DIR:-${BUILD_DIR}}"
      build_with_buildorder "${buildorder}" \
                            "dependencies" \
                            "install" \
                            "build_dependency" \
                            "${builddir}" \
                            "${builddir}/.mulle-built"

      if [ $? -ne 0 -a "${OPTION_LENIENT}" = "NO" ]
      then
         return 1
      fi
   else
      log_verbose "Not building dependencies as DEPENDENCIES_DIR is undefined"
   fi

   log_verbose "Building the rest..."

   build_with_buildorder "${buildorder}" \
                         "normal" \
                         "build" \
                         "build_project" \
                         "${BUILD_DIR:-build}"
}


do_build_execute()
{
   log_entry "do_build_execute" "$@"

   if [ "${OPTION_USE_SOURCETREE}" = "YES" ]
   then
      do_build_sourcetree
      if [ $? -ne 0 -a "${OPTION_LENIENT}" = "YES" ]
      then
         return 0
      fi
      log_verbose "Done with sourcetree built"
   fi

   eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" build "${OPTIONS_MULLE_MAKE}" "$@"
   return $?
}


#
# mulle-build isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
build_execute_main()
{
   log_entry "build_execute_main" "$@"

   local OPTION_USE_SOURCETREE="DEFAULT"
   local OPTION_MODE="--share"
   local OPTION_LENIENT="NO"
   local OPTION_BUILD_STYLE="DEFAULT"
   local OPTIONS_MULLE_MAKE=

   local OPTION_DEPENDENCIES_BUILD_DIR
   local OPTION_INFO_DIR

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h|-help|--help)
            build_execute_usage
         ;;

         -l|--lenient)
            OPTION_LENIENT="YES"
         ;;

         --no-lenient)
            OPTION_LENIENT="NO"
         ;;

         --sourcetree)
            OPTION_USE_SOURCETREE="YES"
         ;;

         --no-sourcetree)
            OPTION_USE_SOURCETREE="NO"
         ;;

         -b|--build-dir)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "$1"`"
            shift

            MULLE_BUILD_DIR="$1"
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "'$1'"`"
         ;;

         --dependencies-build-dir)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            shift

            OPTION_DEPENDENCIES_BUILD_DIR="$1"
         ;;

         -i|--info-dir)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "$1"`"
            shift

            OPTION_INFO_DIR="$1"
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "'$1'"`"
         ;;

         --debug)
            CONFIGURATIONS="Debug"
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "-c 'Debug'"`"
         ;;

         --release)
            CONFIGURATIONS="Release"
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "-c 'Release'"`"
         ;;

         --sdk)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "$1"`"
            shift

            SDKS="$1"
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "'$1'"`"
         ;;

         -r|--recurse|--flat|--share)
            OPTION_MODE="$1"
         ;;

         -*)
            log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown option \"$1\""
            build_execute_usage
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   #
   # check sourcetree existance and handle DEFAULT
   #
   if [ "${OPTION_USE_SOURCETREE}" != "NO" ]
   then
      if [ -f ".mulle-sourcetree" ]
      then
         OPTION_USE_SOURCETREE="YES"
      else
         if [ "${OPTION_USE_SOURCETREE}" = "YES" ]
         then
            fail "No .mulle-sourcetree here ($PWD)"
         else
            log_verbose "No .mulle-sourcetree here ($PWD)"
         fi
         OPTION_USE_SOURCETREE="NO"
      fi
   fi

   if [ -z "${CONFIGURATIONS}" ]
   then
      CONFIGURATIONS="Release"
   fi

   if [ -z "${SDKS}" ]
   then
      SDKS="Default"
   fi

   do_build_execute "$@"
}