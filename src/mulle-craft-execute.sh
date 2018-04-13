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
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${BUILD_STYLE} [options]

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
   --sdk <sdk>               : specify sdk to build against

Environment:
   ADDICTION_DIR   : place to get addictions from (optional)
   BUILD_DIR       : place for build products and by-products
   BUILDINFO_PATH  : places to find mulle-craftinfos
   DEPENDENCY_DIR  : place to put dependencies into (generally required)
EOF
  exit 1
}


build_fetch_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} fetch [options]

   Update the sourcetree, so that all dependencies are properly fetched and
   in place with the correct versions.

Options:
   --recurse|flat|share : specify mode to update sourcetree with

Environment:
   DEPENDENCY_DIR     : place to put dependencies into (generally required)
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

   #
   # for build we do not create "top level" Release files, because it is
   # easier to clean this way
   #
   if [ "${sdk}" = "Default" ]
   then
      echo "/${configuration}"
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
   # in the environment ?=??
   #
   local name="$1"
   local projectdir="$2"
   local projecttype="$3"

   [ -z "${name}" ] && internal_fail "name must not be null"

   local buildinfodir
   local searchpath

   if [ ! -z "${OPTION_INFO_DIR}" ]
   then
      echo "${OPTION_INFO_DIR}"
      return
   fi

   case "${projecttype}" in
      "dependency")
         #
         # I couldn't come up with anything else to store in mulle-craft, so its
         # not /etc/info/... but just ...
         #
         if [ -z "${BUILDINFO_PATH}" ]
         then
            if [ ! -z "${DEPENDENCY_DIR}" ]
            then
               searchpath="`colon_concat "${searchpath}" "${DEPENDENCY_DIR}/share/mulle-craft/${name}.${MULLE_UNAME}" `"
               searchpath="`colon_concat "${searchpath}" "${DEPENDENCY_DIR}/share/mulle-craft/${name}" `"
            fi
            if [ ! -z "${projectdir}" ]
            then
               searchpath="`colon_concat "${searchpath}" "${projectdir}/.mulle-make.${MULLE_UNAME}" `"
               searchpath="`colon_concat "${searchpath}" "${projectdir}/.mulle-make" `"
            fi
         else
            searchpath="`eval echo "${BUILDINFO_PATH}"`"
         fi
      ;;

      "mainproject")
         searchpath="`colon_concat "${searchpath}" "${projectdir}/.mulle-make.${MULLE_UNAME}" `"
         searchpath="`colon_concat "${searchpath}" "${projectdir}/.mulle-make" `"
      ;;

      *)
         internal_fail "Unknown project type \"${projecttype}\""
      ;;
   esac

   log_fluff "Build info searchpath: ${searchpath}"

   IFS=":"
   for buildinfodir in ${searchpath}
   do
      IFS="${DEFAULT_IFS}"
      if [ ! -z "${buildinfodir}" ] && [ -d "${buildinfodir}" ]
      then
         log_info "Info directory \"${buildinfodir}\" found"
         echo "${buildinfodir}"
         return 0
      fi
   done
   IFS="${DEFAULT_IFS}"

   log_fluff "No buildinfo found"

   return 2
}


build_project()
{
   log_entry "build_project" "$@"

   local project="$1"; shift
   local cmd="$1"; shift
   local destination="$1"; shift
   local configuration="$1"; shift
   local sdk="$1"; shift

   local includepath
   local frameworkspath
   local libpath

   if [ ! -z "${DEPENDENCY_DIR}" ]
   then
      includepath="`dependencies_include_path "${configuration}" "${sdk}"`" || return 1
      libpath="`dependencies_lib_path "${configuration}" "${sdk}"`" || return 1
      case "${MULLE_UNAME}" in
         darwin)
            frameworkspath="`dependencies_frameworks_path "${configuration}" "${sdk}"`" || return 1
         ;;
      esac
   fi

   if [ ! -z "${ADDICTION_DIR}" ]
   then
      if [ -d "${ADDICTION_DIR}/include" ]
      then
         includepath="`add_path "${includepath}" "${ADDICTION_DIR}/include"`"
      fi

      if [ -d "${ADDICTION_DIR}/lib" ]
      then
         libpath="`add_path "${libpath}" "${ADDICTION_DIR}/lib"`"
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

   buildinfodir="`determine_buildinfo_dir "${name}" "${project}" "dependency"`"
   [ $? -eq 1 ] && exit 1
   # subdir for configuration / sdk

   local stylesubdir

   stylesubdir="`determine_build_subdir "${configuration}" "${sdk}" `" || return 1

   #
   # find proper build directory
   # find proper log directory
   #
   local builddir
   local logdir

   builddir="${BUILD_DIR:-build}"
   builddir="`filepath_concat "${builddir}" "${name}" `"
   builddir="`filepath_concat "${builddir}" "${stylesubdir}" `"
   logdir="`filepath_concat "${builddir}" ".log" `"

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

   local auxargs
   local i

   for i in "$@"
   do
      if [ -z "${auxargs}" ]
      then
         auxargs="'$1'"
      else
         auxargs="${auxargs} '$1'"
      fi
   done

   eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" \
                          "${cmd}" "${args}" "${auxargs}" \
                          "${project}" "${destination}"
}


build_dependency_directly()
{
   log_entry "build_dependency_directly" "$@"

   local project="$1"; shift

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
                            "${DEPENDENCY_DIR}" \
                            "${configuration}" \
                            "${sdk}" \
                            "$@"
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

   local project="$1"; shift

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

         rmdir_safer "${DEPENDENCY_DIR}.tmp" || return 1

         if build_project "${project}" \
                          "install" \
                          "${DEPENDENCY_DIR}.tmp" \
                          "${configuration}" \
                          "${sdk}" \
                          "$@"
         then
            dependencies_begin_update &&
            exekutor "${MULLE_DISPENSE}" ${MULLE_DISPENSE_FLAGS} dispense \
                        "${DEPENDENCY_DIR}.tmp" "${DEPENDENCY_DIR}${subdir}"  &&
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

   local project="$1" ; shift
   local cmd="$1" ; shift  # unused
   local marks="$1" ; shift

   case "${marks}" in
      *nodispense*)
         build_dependency_directly "${project}" "$@"
      ;;

      *)
         build_dependency_with_dispense  "${project}" "$@"
      ;;
   esac
}


build_subproject()
{
   log_entry "build_subproject" "$@"

   local project="$1" ; shift
   local cmd="$1" ; shift
   local marks="$1" ; shift # unused

   build_project "${project}" "${cmd}" "" "" "" "$@"
}


#
# non-dependencies are build with their own BUILD_DIR
# not in the shared one.
#
build_sourcetree_node()
{
   log_entry "build_sourcetree_line" "$@"

   local project="$1";  shift
   local marks="$1";  shift

   case "${marks}" in
      *,no-dependency,*)
         # subproject or something else
      ;;

      *)
         if [ "${OPTION_BUILD_DEPENDENCY}" = "NO" ]
         then
            log_fluff "Not building dependencies (complying with user wish)"
            return 2
         fi
      ;;
   esac

   local builddir

   builddir="${BUILD_DIR:-build}"
   builddir="${builddir}/.sourcetree"

   log_verbose "Build ${C_MAGENTA}${C_BOLD}${project}${C_VERBOSE}"

   case "${marks}" in
      *,no-dependency,*)
         # functionname will be either build_dependency or build_subproject
         mkdir_if_missing "${builddir}" || fail "Could not create build directory"

         BUILD_DIR="${builddir}" exekutor build_subproject "${project}" \
                                                            "build" \
                                                            "${marks}" \
                                                            "$@"
      ;;

      *)
         [ -z "${DEPENDENCY_DIR}" ] && fail "DEPENDENCY_DIR is undefined"
         [ -z "${CONFIGURATIONS}" ] && internal_fail "CONFIGURATIONS is empty"
         [ -z "${SDKS}" ]           && internal_fail "SDKS is empty"

         builddir="${OPTION_DEPENDENCY_BUILD_DIR:-${builddir}}"
         mkdir_if_missing "${builddir}" || fail "Could not create build directory"

         # functionname will be either build_dependency or build_subproject
         BUILD_DIR="${builddir}" exekutor build_dependency "${project}" \
                                                           "install" \
                                                           "${marks}" \
                                                           "$@"
      ;;
   esac
}


do_build_sourcetree()
{
   log_entry "do_build_sourcetree" "$@"

   [ -z "${MULLE_CRAFT_DEPENDENCY_SH}" ] && . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-dependencies.sh"

   do_update_sourcetree # hmm

   local buildorder
   local builddir

   buildorder="`exekutor "${MULLE_SOURCETREE}" ${MULLE_SOURCETREE_FLAGS} buildorder --marks`" || exit 1
   if [ -z "${buildorder}" ]
   then
      log_verbose "There is nothing to build according to ${MULLE_SOURCETREE}"
      return
   fi

   local remaining
   local donefile

   donefile="${BUILD_DIR}/.mulle-craft-built"
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

      build_sourcetree_node "${project}" "${marks}"
      case $? in
         0)
            if [ ! -z "${donefile}" ]
            then
               redirect_append_exekutor "${donefile}" echo "${line}"
            fi
         ;;

         1)
            if [ "${OPTION_LENIENT}" = "NO" ]
            then
               log_fluff "Build of \"${project}\" failed, so quit"
               return 1
            fi
            log_fluff "Ignore failure of \"${project}\" due to leniency option"
         ;;

         # 2 just ignored, but not remembered
      esac
   done

   IFS="${DEFAULT_IFS}"
}


#
# need a different name for the mainproject here
#
do_build_mainproject()
{
   log_entry "do_build_mainproject" "$@"

   local buildinfodir
   local name

   name="${PROJECT_NAME}"
   if [ -z "${PROJECT_NAME}" ]
   then
      name="`fast_basename "${PWD}"`"
   fi

   log_verbose "Build ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE} with ${MULLE_MAKE}"

   buildinfodir="`determine_buildinfo_dir "${name}" "${project}" "mainproject"`"

   if [ ! -z "${buildinfodir}" ]
   then
      OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--info-dir '${buildinfodir}'" `"
   fi

   local stylesubdir

   stylesubdir="`determine_build_subdir "${CONFIGURATIONS}" "${SDKS}" `" || return 1

   #
   # find proper build directory
   # find proper log directory
   #
   local builddir
   local logdir

   builddir="${BUILD_DIR:-build}"
   builddir="`filepath_concat "${builddir}" "${stylesubdir}" `"
   logdir="`filepath_concat "${builddir}" ".logs" `"


   [ $? -eq 1 ] && exit 1

   OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--build-dir '${builddir}'"`"
   OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--log-dir '${logdir}'"`"


   # never install the project, use mulle-make for that
   if ! eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" \
                        "build" "${OPTIONS_MULLE_MAKE_PROJECT}" "$@"
   then
      log_fluff "project build failed"
      return 1
   fi

   if [ "${MULLE_FLAG_MOTD}" = "NO" ]
   then
      log_fluff "Not showing motd on request"
   else
      if [ -f "${BUILD_DIR}/.motd" ]
      then
         log_fluff "Showing \"${BUILD_DIR}/.motd\""
         exekutor cat "${BUILD_DIR}/.motd"
      else
         log_fluff "No \"${BUILD_DIR}/.motd\" was produced"
      fi
   fi
}


do_build_execute()
{
   log_entry "do_build_execute" "$@"

   local lastenv
   local currentenv
   local filenameenv

   [ -z "${BUILD_DIR}" ] && internal_fail "BUILD_DIR not set"
   [ -z "${MULLE_UNAME}" ] && internal_fail "MULLE_UNAME not set"
   [ -z "${LOGNAME}" ] && internal_fail "LOGNAME not set"

   filenameenv="${BUILD_DIR}/.mulle-craft"
   currentenv="${MULLE_UNAME};`hostname`;${LOGNAME}"

   lastenv="`egrep -s -v '^#' "${filenameenv}"`"
   if [ "${lastenv}" != "${currentenv}" ]
   then
      rmdir_safer "${BUILD_DIR}"
      mkdir_if_missing "${BUILD_DIR}"
      redirect_exekutor "${filenameenv}" echo "# mulle-craft environment info
${currentenv}"
   fi

   local rval

   rval=0
   if [ "${OPTION_USE_SOURCETREE}" = "YES" ]
   then
      if ! do_build_sourcetree "$@"
      then
         if [ "${OPTION_LENIENT}" = "NO" ]
         then
            log_error "Sourcetree build failed and we aren't lenient"
            return 1
         fi
         rval=1
      fi
      log_fluff "Done with sourcetree built"
   else
      log_fluff "Not building sourcetree (complying with user wish)"
   fi

   #
   # Build the project
   #
   if [ "${OPTION_USE_PROJECT}" = "YES" ]
   then
      if ! do_build_mainproject "$@"
      then
         rval=1
      fi
   else
      log_fluff "Not building project (complying with user wish)"
   fi

   return $rval
}


do_update_sourcetree()
{
   log_entry "do_update_sourcetree" "$@"

   if ! exekutor "${MULLE_SOURCETREE}" ${MULLE_SOURCETREE_FLAGS} status --is-uptodate
   then
      eval_exekutor "'${MULLE_SOURCETREE}'" \
                        "${MULLE_SOURCETREE_FLAGS}" "${OPTION_MODE}" \
                        "update" "$@" || exit 1
   fi
}


#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde
#
build_common()
{
   log_entry "build_common" "$@"

   local OPTION_MODE="--share"
   local OPTION_LENIENT="NO"
   local OPTION_BUILD_DEPENDENCY="DEFAULT"
   local OPTIONS_MULLE_MAKE_PROJECT=
   local OPTION_INSTALL_PROJECT="NO"

   local OPTION_INFO_DIR
   local OPTION_SOURCETREE_ARGS

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            build_execute_usage
         ;;

         -l|--lenient)
            OPTION_LENIENT="YES"
         ;;

         --no-lenient)
            OPTION_LENIENT="NO"
         ;;

         --dependency)
            OPTION_BUILD_DEPENDENCY="YES"
         ;;

         --only-dependency)
            OPTION_BUILD_DEPENDENCY="ONLY"
         ;;

         --no-dependency)
            OPTION_BUILD_DEPENDENCY="NO"
         ;;

         -b|--build-dir)
            [ $# -eq 1 ] && build_execute_usage "missing argument to \"$1\""
            shift

            BUILD_DIR="$1"
         ;;

         -i|--info-dir)
            [ $# -eq 1 ] && build_execute_usage "missing argument to \"$1\""
            shift

            OPTION_INFO_DIR="$1"
         ;;

         --debug)
            CONFIGURATIONS="Debug"
         ;;

         --release)
            CONFIGURATIONS="Release"
         ;;

         --sdk)
            [ $# -eq 1 ] && build_execute_usage "missing argument to \"$1\""
            shift

            SDKS="$1"
         ;;

         -r|--recurse|--flat|--share)
            OPTION_MODE="$1"
         ;;

         -V|--verbose-make)
            MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "'$1'"`"
         ;;

         --)
            shift
            break
         ;;

         -*)
            build_execute_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local projectdir

   projectdir="`exekutor ${MULLE_SDE} ${MULLE_SDE_FLAGS} "project-dir" ${MULLE_FLAG_DEFER}`"

   if [ ! -z "${projectdir}" ]
   then
      if [ "${projectdir}" != "${PWD}" ]
      then
         log_verbose "Found a mulle-sde project in \"${projectdir}\""
      fi
      cd "${projectdir}"
   fi

   local MAIN_PROJECT_DIR

   MAIN_PROJECT_DIR="${PWD}"

   local sourcetreedir

   sourcetreedir="`exekutor ${MULLE_SOURCETREE} ${MULLE_SOURCETREE_FLAGS} \
                            ${MULLE_FLAG_DEFER} "sourcetree-dir" `"
   if [ -z "${sourcetreedir}" -o "${sourcetreedir}" != "${MAIN_PROJECT_DIR}" ]
   then
      if [ "${OPTION_MUST_HAVE_SOURCETREE}" = "YES" ]
      then
         fail "There is no sourcetree here ($PWD)"
      fi

      log_fluff "No sourcetree found ($PWD)"
      OPTION_USE_SOURCETREE="NO"
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


build_fetch_main()
{
   log_entry "build_fetch_main" "$@"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            build_fetch_usage
         ;;

         -r|--recurse|--flat|--share)
            OPTION_MODE="$1"
         ;;

         --)
            shift
            break
         ;;

         -*)
            build_fetch_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   [ "$#" -eq 0 ] || build_fetch_usage "superflous arguments \"$*\""

   do_update_sourcetree "$@"
}

