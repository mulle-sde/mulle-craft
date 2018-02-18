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
MULLE_CRAFT_EXECUTE_SH="included"


build_execute_usage()
{
    cat <<EOF >&2
Usage:
   ${MULLE_EXECUTABLE_NAME} ${BUILD_STYLE} [options]

   ${USAGE_INFO}

Options:
   --build-dir <dir>         : set BUILD_DIR
   --debug                   : compile for debug only
   --info-dir <dir>          : specify the buildinfo for mulle-make (project)
   --lenient                 : do not stop on errors
   --only-dependencies       : build dependencies only
   --no-dependencies         : don't build dependencies
   --recurse|flat|share      : specify mode to update sourcetree with
   --release                 : compile for release only
   --sdk

Environment:
   ADDICTIONS_DIR   : place to get addictions from (optional)
   BUILD_DIR        : place for build products and by-products
   BUILDINFO_PATH   : places to find mulle-craftinfos
   DEPENDENCIES_DIR : place to put dependencies into (generally required)
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
   local style="${3:-auto}"

   [ -z "${configuration}" ] && internal_fail "configuration must not be empty"
   [ -z "${sdk}" ]           && internal_fail "sdk must not be empty"
   [ -z "${SDKS}" ]          && internal_fail "SDKS must not be empty"

   sdk=`echo "${sdk}" | "${SED:-sed}" 's/^\([a-zA-Z]*\).*$/\1/g'`

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

   #
   # upper case for the sake of sameness for ppl setting BUILDINFO_PATH
   # in the environment
   #
   local NAME="$1"
   local PROJECT_DIR="$2"

   local buildinfodir
   local searchpath

   if [ -z "${BUILDINFO_PATH}" ]
   then
      searchpath="`colon_concat "${searchpath}" "${DEPENDENCIES_DIR}/share/mulle-craft/mulle-make/${NAME}.${MULLE_UNAME}" `"
      searchpath="`colon_concat "${searchpath}" "${DEPENDENCIES_DIR}/share/mulle-craft/mulle-make/${NAME}" `"
      searchpath="`colon_concat "${searchpath}" "${PROJECT_DIR}/.mulle-make.${MULLE_UNAME}" `"
      searchpath="`colon_concat "${searchpath}" "${PROJECT_DIR}/.mulle-make" `"
   else
      searchpath="`eval echo "${BUILDINFO_PATH}"`"
   fi

   log_fluff "Build info searchpath: ${searchpath}"

   IFS=":"
   for buildinfodir in ${searchpath}
   do
      IFS="${DEFAULT_IFS}"
      if [ ! -z "${buildinfodir}" ] && [ -d "${buildinfodir}" ]
      then
         echo "${buildinfodir}"
         return 0
      fi
   done
   IFS="${DEFAULT_IFS}"

   log_fluff "No buildinfo found"

   return 1
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
      case "${MULLE_UNAME}" in
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
   # dependencies/share/mulle-craftinfo/<name>.txt
   # <project>/.mulle-craftinfo
   #
   local name

   name="`extensionless_basename "${project}"`"

   local buildinfodir

   buildinfodir="`determine_buildinfo_dir "${name}" "${project}"`"

   # subdir for configuration / sdk

   local stylesubdir

   stylesubdir="`determine_build_subdir "${configuration}" "${sdk}" `"

   #
   # find proper build directory
   # find proper log directory
   #
   local builddir
   local logdir

   builddir="${BUILD_DIR:-build}"
   builddir="`filepath_concat "${builddir}" "${name}" `"
   logdir="${builddir}/.logs"

   builddir="`filepath_concat "${builddir}" "${stylesubdir}" `"
   logdir="`filepath_concat "${logdir}" "${stylesubdir}" `"

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
   if [ ! -z "${destination}" ]
   then
      args="`concat "${args}" "--prefix '${destination}'" `"
   fi

   if [ "${cmd}" != "install" ]
   then
      destination=""
   fi

   eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" \
                          "${cmd}" "${args}" "${project}" "${destination}"

 }


build_dependency_directly()
{
   log_entry "build_dependency_directly" "$@"

   local project="$1"
   local rval

   dependencies_begin_update || return 1

   #
   # build first configuration and sdk only
   #
   local configuration
   local sdk
   local rval

   rval=0

   IFS=","
   for configuration in ${CONFIGURATIONS}
   do
      IFS=","
      if [ -z "${configuration}" ]
      then
         continue
      fi

      for sdk in ${SDKS}
      do
         IFS="${DEFAULT_IFS}"

         if [ -z "${sdk}" ]
         then
            continue
         fi

         if ! build_project "${project}" \
                            "install" \
                            "${DEPENDENCIES_DIR}" \
                            "${configuration}" \
                            "${sdk}"
         then
            if [ "${OPTION_LENIENT}" = "NO" ]
            then
               return 1
            fi
            rval=1
         fi
      done
   done
   IFS="${DEFAULT_IFS}"

   dependencies_end_update || return 1

   # signal failures downward, even if lenient
   return $rval
}


build_dependency_with_dispense()
{
   log_entry "build_dependency_with_dispense" "$@"

   local project="$1"
   local rval

   rval=0

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

         if build_project "${project}" \
                          "install" \
                          "${DEPENDENCIES_DIR}.tmp" \
                          "${configuration}" \
                          "${sdk}"
         then
            dependencies_begin_update &&
            exekutor "${MULLE_DISPENSE}" ${MULLE_DISPENSE_FLAGS} dispense \
                        "${DEPENDENCIES_DIR}.tmp" "${DEPENDENCIES_DIR}${subdir}"  &&
            dependencies_end_update
         else
            log_fluff "build_project \"${project}\" failed"
            if [ "${OPTION_LENIENT}" = "NO" ]
            then
               return 1
            fi
            rval=1
         fi
      done
   done
   IFS="${DEFAULT_IFS}"

   return $rval
}


build_dependency()
{
   log_entry "build_dependency" "$@"

   local project="$1"
   local marks="$2"

   local buildfunction

   buildfunction="build_dependency_with_dispense"

   case "${marks}" in
      *nodispense*)
         buildfunction="build_dependency_directly"
      ;;
   esac

   "${buildfunction}" "${project}"
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

      log_verbose "Build ${C_MAGENTA}${C_BOLD}${project}${C_VERBOSE}"

      (
         BUILD_DIR="${builddir}" "${functionname}" "${project}" \
                                                   "${cmd}" \
                                                   "${marks}"
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
            log_fluff "Build of \"${project}\" failed, so quit"
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

   [ -z "${MULLE_CRAFT_DEPENDENCIES_SH}" ] && . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-dependencies.sh"


   local sourcetree_update_options

   #
   # these are environment variables
   #
   sourcetree_update_options="${MULLE_SOURCETREE_UPDATE_OPTIONS}"

   if [ "${MULLE_SYMLINK}" = "YES" ]
   then
      sourcetree_update_options="`concat "${sourcetree}" "--symlink" `"
   fi

   if ! exekutor "${MULLE_SOURCETREE}" ${MULLE_SOURCETREE_FLAGS} status --is-uptodate
   then
      eval_exekutor "'${MULLE_SOURCETREE}'" \
                        "${MULLE_SOURCETREE_FLAGS}" "${OPTION_MODE}" \
                        "update" \
                          "${sourcetree_update_options}" || exit 1
   fi

   local buildorder
   local builddir

   buildorder="`"${MULLE_SOURCETREE}" ${MULLE_SOURCETREE_FLAGS} buildorder --marks`" || exit 1
   if [ -z "${buildorder}" ]
   then
      log_verbose "Nothing to build according to ${MULLE_SOURCETREE}"
      return
   fi

   local rval

   rval=0
   if [ "${OPTION_BUILD_DEPENDENCIES}" != "NO" ]
   then
      if [ ! -z "${DEPENDENCIES_DIR}" ]
      then
         log_verbose "Building the dependencies of the sourcetree ..."

         builddir="${BUILD_DIR:-build}"
         builddir="${OPTION_DEPENDENCIES_BUILD_DIR:-${builddir}}"

         if ! build_with_buildorder "${buildorder}" \
                                    "dependencies" \
                                    "install" \
                                    "build_dependency" \
                                    "${builddir}" \
                                    "${builddir}/.mulle-built"
         then
            if [ "${OPTION_LENIENT}" = "NO" ]
            then
               return 1
            fi
            rval=1
         fi
      else
         log_verbose "Not building dependencies as DEPENDENCIES_DIR is undefined"
      fi
      if [ "${OPTION_BUILD_DEPENDENCIES}" = "ONLY" ]
      then
         log_fluff "Building dependencies only, so done here"
         return $rval
      fi
   else
      log_fluff "Not building dependencies (complying with user wish)"
   fi

   log_verbose "Building the rest of the sourcetree ..."

   if ! build_with_buildorder "${buildorder}" \
                              "normal" \
                              "build" \
                              "build_project" \
                              "${BUILD_DIR:-build}"
   then
      return 1
   fi

   return $rval
}


do_build_execute()
{
   log_entry "do_build_execute" "$@"

   local rval

   rval=0
   if [ "${OPTION_USE_SOURCETREE}" = "YES" ]
   then
      if ! do_build_sourcetree
      then
         if [ "${OPTION_LENIENT}" = "NO" ]
         then
            log_fluff "Sourcetree build failed and we aren't lenient"
            return 1
         fi
         rval=1
      fi
      log_fluff "Done with sourcetree built"
   else
      log_fluff "Not building sourcetree (complying with user wish)"
   fi

   if [ "${OPTION_USE_PROJECT}" = "YES" ]
   then
      log_verbose "Building the project (outside of the sourcetree) ..."
      log_verbose "Build ${C_MAGENTA}${C_BOLD}${PWD}${C_VERBOSE} with ${MULLE_MAKE}"

      if ! eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" build "${OPTIONS_MULLE_MAKE}" "$@"
      then
         log_fluff "project build failed"
         return 1
      fi

      if [ "${MULLE_FLAG_MOTD}" = "YES" ]
      then
         if [ -f "${BUILD_DIR}/.motd" ]
         then
            log_fluff "Showing \"${BUILD_DIR}/.motd\""
            exekutor cat "${BUILD_DIR}/.motd"
         else
            log_fluff "No \"${BUILD_DIR}/.motd\" was produced"
         fi
      else
         log_fluff "Not showing motd on request"
      fi
   else
      log_fluff "Not building project (complying with user wish)"
   fi

   return $rval
}


#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
build_common()
{
   log_entry "build_common" "$@"

   local OPTION_USE_SOURCETREE="DEFAULT"
   local OPTION_MODE="--share"
   local OPTION_LENIENT="NO"
   local OPTION_BUILD_DEPENDENCIES="DEFAULT"
   local OPTIONS_MULLE_MAKE=

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

         --dependencies)
            OPTION_BUILD_DEPENDENCIES="YES"
         ;;

         --only-dependencies)
            OPTION_BUILD_DEPENDENCIES="ONLY"
         ;;

         --no-dependencies)
            OPTION_BUILD_DEPENDENCIES="NO"
         ;;

         -b|--build-dir)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "$1"`"
            shift

            BUILD_DIR="$1"
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "'$1'"`"
         ;;

         -i|--info-dir)
            [ $# -eq 1 ] && fail "missing argument to \"$1\""
            OPTIONS_MULLE_MAKE="`concat "${OPTIONS_MULLE_MAKE}" "$1"`"
            shift

            # not really used, OPTIONS_MULLE_MAKE is used
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

   # for consistency always find the sourcetree
   local projectdir

   projectdir="`exekutor ${MULLE_SOURCETREE} ${MULLE_SOURCETREE_FLAGS} \
                              ${MULLE_FLAG_DEFER} "sourcetree-dir" `"
   if [ ! -z "${projectdir}" ]
   then
      log_verbose "Found a sourcetree in \"${projectdir}\""
      cd "${projectdir}"
   else
      if [ "${OPTION_MUST_HAVE_SOURCETREE}" = "YES" ]
      then
         fail "There is no sourcetree here ($PWD)"
      else
         log_fluff "No sourcetree found ($PWD)"
      fi
   fi

   #
   # check sourcetree existance and handle DEFAULT
   #
   if [ "${OPTION_USE_SOURCETREE}" != "NO" ]
   then
      if [ -d ".mulle-sourcetree" ]
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


build_all_main()
{
   log_entry "build_all_main" "$@"

   BUILD_STYLE="all"

   USAGE_INFO="Build the sourcetree, containing the dependencies.
   Then build the project.
"

   local OPTION_USE_PROJECT
   local OPTION_USE_SOURCETREE
   local OPTION_MUST_HAVE_SOURCETREE

   OPTION_USE_PROJECT="YES"
   OPTION_USE_SOURCETREE="YES"
   OPTION_MUST_HAVE_SOURCETREE="NO"

   build_common "$@"
}


build_project_main()
{
   log_entry "build_project_main" "$@"

   BUILD_STYLE="project"

   USAGE_INFO="Build the project only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_SOURCETREE
   local OPTION_MUST_HAVE_SOURCETREE

   OPTION_USE_PROJECT="YES"
   OPTION_USE_SOURCETREE="NO"
   OPTION_MUST_HAVE_SOURCETREE="NO"

   build_common "$@"
}


build_sourcetree_main()
{
   log_entry "build_sourcetree_main" "$@"

   BUILD_STYLE="sourcetree"

   USAGE_INFO="Build the sourcetree only.
"

   local OPTION_USE_PROJECT
   local OPTION_USE_SOURCETREE
   local OPTION_MUST_HAVE_SOURCETREE

   OPTION_USE_PROJECT="NO"
   OPTION_USE_SOURCETREE="YES"
   OPTION_MUST_HAVE_SOURCETREE="YES"


   build_common "$@"
}
