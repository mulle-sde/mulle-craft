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
   --debug           : compile for debug only
   --lenient         : do not stop on errors
   --release         : compile for release only
   --sdk <sdk>       : specify sdk to build against
   --                : pass remaining options to mulle-make
   -V                : more verbose output from make tools

Environment:
   ADDICTION_DIR     : place to get addictions from (optional)
   BUILD_DIR         : place for build products and by-products
   BUILDINFO_PATH    : places to find mulle-craftinfos
   DEPENDENCY_DIR    : place to put dependencies into (generally required)
EOF
  exit 1
}

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

   sdk="`LC_ALL=C "${SED:-sed}" 's/^\([a-zA-Z]*\).*$/\1/g' <<< "${sdk}" `"

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

   sdk="`LC_ALL=C "${SED:-sed}" 's/^\([a-zA-Z]*\).*$/\1/g' <<< "${sdk}" `"

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


build_project()
{
   log_entry "build_project" "$@"

   local cmd="$1"; shift
   local destination="$1"; shift

   local project="$1"
   local name="$2"
   local marks="$3"
   local builddir="$4"
   local configuration="$5"
   local sdk="$6"

   shift 6

   [ -z "${cmd}" ]         && internal_fail "cmd is empty"
   [ -z "${destination}" ] && internal_fail "destination is empty"
  
   [ -z "${project}" ]     && internal_fail "project is empty"
   [ -z "${name}" ]        && internal_fail "name is empty"
   [ -z "${builddir}" ]    && internal_fail "builddir is empty"

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
   local dirname

   #
   # remove any non-identifiers and file extension from name
   #
   dirname="`tr -c 'a-zA-Z0-9-' '_' <<< "${name%.*}" | sed -e 's/_$//g'`"

   #
   # find proper build directory
   # find proper log directory
   #
   local buildparentdir

   buildparentdir="${builddir}"

   local logdir

   builddir="`filepath_concat "${buildparentdir}" "${dirname}" `"

   #
   # if projects exist with duplicate names, add a random number at end
   # to differentiate
   #
   local randomstring

   case ",${marks}," in
      *,no-memo,*)
         # usally a subproject
      ;;

      *)
         while [ -d "${builddir}" ]
         do
            randomstring="`uuidgen | cut -c'1-6'`"
            builddir="`filepath_concat "${buildparentdir}" "${dirname}-${randomstring}" `"
         done
      ;;
   esac

   mkdir_if_missing "${builddir}" || fail "Could not create build directory"

   logdir="`filepath_concat "${builddir}" ".log" `"

   local buildinfodir

   buildinfodir="`determine_buildinfo_dir "${name}" "${project}" "dependency"`"
   case $? in
      0|2)
      ;;

      *)
         exit 1
      ;;
   esac

   # subdir for configuration / sdk

   #
   # call mulle-make with all we've got now
   #
   local args

   args="${OPTIONS_MULLE_MAKE}"

   if [ ! -z "${name}" ]
   then
      args="`concat "${args}" "--name '${name}'" `"
   fi
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
         auxargs="'${i}'"
      else
         auxargs="${auxargs} '${i}'"
      fi
   done

   eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" \
                          "${cmd}" "${args}" "${auxargs}" \
                          "${project}" "${destination}"
}


build_dependency_directly()
{
   log_entry "build_dependency_directly" "$@"

   local project="$1"
   local name="$2"
   local marks="$3"
   local builddir="$4"
   local configuration="$5"
   local sdk="$6"

   dependencies_begin_update || return 1

   local rval

   rval=0

   build_project "install" "${DEPENDENCY_DIR}" "$@"
   rval=$?

   if [ $rval -ne 0 ]
   then
      log_fluff "Build of project \"${project}\" failed with $rval"
      if [ "${OPTION_LENIENT}" = "NO" ]
      then
         return 1
      fi
      rval=1
   fi

   dependencies_end_update || return 1

   # signal failures downward, even if lenient
   return $rval
}


build_dependency_with_dispense()
{
   log_entry "build_dependency_with_dispense" "$@"

   local project="$1"
   local name="$2"
   local marks="$3"
   local builddir="$4"
   local configuration="$5"
   local sdk="$6"

   local rval

   rval=0

   rmdir_safer "${DEPENDENCY_DIR}.tmp" || return 1

   build_project "install" "${DEPENDENCY_DIR}.tmp" "$@"
   rval=$?

   if [ $rval -eq 0 ]
   then
      stylesubdir="`determine_dependencies_subdir "${configuration}" \
                                                  "${sdk}" \
                                                  "${MULLE_DISPENSE_STYLE}" `"

      dependencies_begin_update &&
      exekutor "${MULLE_DISPENSE}" ${MULLE_TECHNICAL_FLAGS} \
                  ${MULLE_DISPENSE_FLAGS} dispense \
                  "${DEPENDENCY_DIR}.tmp" \
                  "${DEPENDENCY_DIR}${stylesubdir}" &&
      dependencies_end_update
   else
      log_fluff "Build of project \"${project}\" failed with $rval"
      if [ "${OPTION_LENIENT}" = "NO" ]
      then
         return 1
      fi
      rval=1
   fi

   return $rval
}


build_dependency()
{
   log_entry "build_dependency" "$@"

   local cmd="$1"; shift  # don't need it

#   local project="$1"
#   local name="$2"
   local marks="$3"
#   local builddir="$4"
#   local configuration="$5"
#   local sdk="$6"

   case ",${marks}," in
      *,no-dispense,*)
         build_dependency_directly "$@"
      ;;

      *)
         build_dependency_with_dispense "$@"
      ;;
   esac
}


#
# non-dependencies are build with their own BUILD_DIR
# not in the shared one.
#
build_buildorder_node()
{
   log_entry "build_buildorder_node" "$@"

   local project="$1"
#   local name="$2"
   local marks="$3"
#   local builddir="$4"
#   local configuration="$5"
#   local sdk="$6"

   case ",${marks}," in
      *,no-dependency,*)
         # subproject or something else
      ;;

      *)
         if [ "${OPTION_BUILD_DEPENDENCY}" = "NO" ]
         then
            log_fluff "Not building dependency \"${project}\" (complying with user wish)"
            return 2
         fi
      ;;
   esac

   # the buildorder should have filtered these out already
   case ",${marks}," in
      *",only-os-${MULLE_UNAME}",*)
         # nice
      ;;

      *",only-os-"*","*|*",no-os-${MULLE_UNAME},"*)
         fail "The buildorder ${C_RESET_BOLD}${BUILDORDER_FILE#${MULLE_USER_PWD}/}${C_ERROR} was made for a different platform. Time to clean. "
      ;;
   esac

   log_verbose "Build ${C_MAGENTA}${C_BOLD}${project}${C_VERBOSE}"

   build_dependency "install" "$@"
}


_do_build_buildorder()
{
   local buildorder="$1"
   local builddir="$2"
   local configuration="$3"
   local sdk="$4"

   local donefile
   local subdir

   subdir="`determine_build_subdir "${configuration}" "${sdk}" `"
   builddir="`filepath_concat "${builddir}" "${subdir}" `"

   mkdir_if_missing "${builddir}"

   donefile="${builddir}/.mulle-craft-built"

   local remaining

   remaining="${buildorder}"
   if [ ! -z "${donefile}" ]
   then
      if [ -f "${donefile}" ]
      then
         remaining="`fgrep -x -v -f "${donefile}" <<< "${buildorder}"`"
         if [ -z "${remaining}" ]
         then
            log_verbose "Everything in the buildorder has been built already"
            return
         fi
      fi
   fi

   local line

   set -f ; IFS="
"
   for line in ${remaining}
   do
      set +f ; IFS="${DEFAULT_IFS}"

      local project
      local evaledproject
      local marks
      local name

      IFS=";" read project marks <<< "${line}"

      if [ -z "${project}" ]
      then
         internal_fail "empty project fail"
      fi

      evaledproject="`eval echo "${project}"`"
      name="${project#'${MULLE_SOURCETREE_SHARE_DIR}/'}"

      build_buildorder_node "${evaledproject}" \
                            "${name}" \
                            "${marks}" \
                            "${builddir}" \
                            "${configuration}" \
                            "${sdk}" 
      case $? in
         0)
            case ",${marks}," in
               *,no-memo,*)
                  # usally a subproject
               ;;

               *)
                  if [ ! -z "${donefile}" ]
                  then
                     redirect_append_exekutor "${donefile}" echo "${line}"
                  fi
               ;;
            esac
         ;;

         1)
            if [ "${OPTION_LENIENT}" = "NO" ]
            then
               log_debug "Build of \"${evaledproject}\" failed, so quit"
               return 1
            fi
            log_fluff "Ignoring build failure of \"${evaledproject}\" due to leniency option"
         ;;

         # 2 just ignored, but not remembered
      esac
   done

   set +f ; IFS="${DEFAULT_IFS}"
}


do_build_buildorder()
{
   log_entry "do_build_buildorder" "$@"

   local buildorderfile="$1"
   local builddir="$2"

   # shellcheck source=mulle-env-dependencies.sh
   [ -z "${MULLE_CRAFT_DEPENDENCY_SH}" ] && . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-dependencies.sh"

   local buildorder

   buildorder="`egrep -v '^#' "${buildorderfile}" 2> /dev/null`"
   [ $? -eq 2 ] && fail "Buildorder \"${buildorderfile}\" is missing"

   #
   # Do this once initially, even if there are no dependencies
   # That allows tarballs to be installed. Also now the existance of the
   # dependencies folders, means something
   #
   dependencies_begin_update || exit 1
   dependencies_end_update || exit 1

   if [ -z "${buildorder}" ]
   then
      log_verbose "The buildorder file is empty, nothing to build (${buildorderfile#${MULLE_USER_PWD}/})"
      return
   fi

   [ -z "${DEPENDENCY_DIR}" ] && fail "DEPENDENCY_DIR is undefined"
   [ -z "${CONFIGURATIONS}" ] && internal_fail "CONFIGURATIONS is empty"
   [ -z "${SDKS}" ]           && internal_fail "SDKS is empty"

   local configuration
   local sdk

   set -f; IFS=","
   for configuration in ${CONFIGURATIONS}
   do
      for sdk in ${SDKS}
      do
         set +f; IFS="${DEFAULT_IFS}"

         if ! _do_build_buildorder "${buildorder}" \
                                   "${builddir}"\
                                   "${configuration}" \
                                   "${sdk}"
         then
            return 1
         fi 
         set -f; IFS=","
      done
   done
   set +f ; IFS="${DEFAULT_IFS}"
}



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

   buildinfodir="`determine_buildinfo_dir "${name}" "${PWD}" "mainproject"`"

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
   logdir="`filepath_concat "${builddir}" ".log" `"

   [ $? -eq 1 ] && exit 1

   OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--build-dir '${builddir}'"`"
   OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--log-dir '${logdir}'"`"

   # ugly hackage
   if [ ! -z "${CONFIGURATIONS}" ]
   then
      OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--configuration '${CONFIGURATIONS%%,*}'" `"
   fi
   if [ ! -z "${SDKS}" ]
   then
      OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--sdk '${SDKS%%,*}'" `"
   fi

   # never install the project, use mulle-make for that
   if ! eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" \
                        "build" "${OPTIONS_MULLE_MAKE_PROJECT}" "$@"
   then
      log_fluff "Project build failed"
      return 1
   fi

   if [ "${MULLE_FLAG_MOTD}" = "NO" ]
   then
      log_fluff "Not showing motd on request"
   else
      if [ -f "${builddir}/.motd" ]
      then
         log_fluff "Showing \"${builddir}/.motd\""
         exekutor cat "${builddir}/.motd"
      else
         log_fluff "No \"${builddir}/.motd\" was produced"
      fi
   fi
}

#
# mulle-craft isn't rules so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde.
#
build_common()
{
   log_entry "build_common" "$@"

   local OPTION_LENIENT="NO"
   local OPTION_BUILD_DEPENDENCY="DEFAULT"
   local OPTIONS_MULLE_MAKE_PROJECT=
   local OPTION_SUBDIR=".buildorder"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            build_execute_usage
         ;;

         -f|--buildorder-file)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            BUILDORDER_FILE="$1"  # could be global env
         ;;

         -s|--subdir)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            OPTION_SUBDIR="$1"  # could be global env
         ;;

         -l|--lenient)
            OPTION_LENIENT="YES"
         ;;

         --no-lenient)
            OPTION_LENIENT="NO"
         ;;

         # these are dependency within buildorder, buildorder has also subproj
         --dependency)
            OPTION_BUILD_DEPENDENCY="YES"
         ;;

         --only-dependency)
            OPTION_BUILD_DEPENDENCY="ONLY"
         ;;

         --no-dependency)
            OPTION_BUILD_DEPENDENCY="NO"
         ;;

         --debug)
            CONFIGURATIONS="Debug"
         ;;

         --release)
            CONFIGURATIONS="Release"
         ;;

         --sdk)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            SDKS="$1"
         ;;

         -V|--verbose-make)
            OPTIONS_MULLE_MAKE_PROJECT="`concat "${OPTIONS_MULLE_MAKE_PROJECT}" "'$1'"`"
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

   if [ -z "${CONFIGURATIONS}" ]
   then
      CONFIGURATIONS="Release"
   fi

   if [ -z "${SDKS}" ]
   then
      SDKS="Default"
   fi

   local lastenv
   local currentenv
   local filenameenv

   [ -z "${BUILD_DIR}" ] && internal_fail "BUILD_DIR not set"
   [ -z "${MULLE_UNAME}" ] && internal_fail "MULLE_UNAME not set"

   filenameenv="${BUILD_DIR}/.mulle-craft"
   currentenv="${MULLE_UNAME};${MULLE_HOSTNAME};${LOGNAME:-`id -u`}"

   lastenv="`egrep -s -v '^#' "${filenameenv}"`"
   if [ "${lastenv}" != "${currentenv}" ]
   then
      rmdir_safer "${BUILD_DIR}"
      mkdir_if_missing "${BUILD_DIR}"
      redirect_exekutor "${filenameenv}" echo "# mulle-craft environment info
${currentenv}"
   fi

   if [ -z "${MULLE_CRAFT_SEARCH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-search.sh" || exit 1
   fi

   if [ "${OPTION_USE_BUILDORDER}" = "YES" ]
   then
      #
      # the buildorderfile is created by mulle-sde
      # mulle-craft searches no default path
      #
      if [ -z "${BUILDORDER_FILE}" ]
      then
         fail "Failed to specify buildorder with --buildorder-file <file>"
      fi

      if [ ! -f "${BUILDORDER_FILE}" ]
      then
         fail "Missing buildorder file \"${BUILDORDER_FILE}\""
      fi

      local builddir
      local subdir

      builddir="${OPTION_BUILDORDER_BUILD_DIR:-${BUILD_DIR}}"
      builddir="`filepath_concat "${builddir}" "${OPTION_SUBDIR}"`"

      do_build_buildorder "${BUILDORDER_FILE}" "${builddir}"
      return $?
   fi

   #
   # Build the project
   #
   [ "${OPTION_USE_PROJECT}" = "YES" ] || internal_fail "hein ?"

   do_build_mainproject "$@"
}


build_project_main()
{
   log_entry "build_project_main" "$@"

   BUILD_STYLE="project"

   USAGE_INFO="Build the project only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT="YES"
   OPTION_USE_BUILDORDER="NO"
   OPTION_MUST_HAVE_BUILDORDER="NO"

   build_common "$@"
}


build_buildorder_main()
{
   log_entry "build_buildorder_main" "$@"

   BUILD_STYLE="buildorder"

   USAGE_INFO="Build the buildorder only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT="NO"
   OPTION_USE_BUILDORDER="YES"
   OPTION_MUST_HAVE_BUILDORDER="YES"

   build_common "$@"
}

