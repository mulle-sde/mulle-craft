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
   --f <buildorder>  : specify buildorder file
   --debug           : compile for debug only
   --lenient         : do not stop on errors
   --no-protect      : do not make dependency read-only
   --rebuild         : rebuild every dependency buildorder
   --release         : compile for release only
   --sdk <sdk>       : specify sdk to build against
   --                : pass remaining options to mulle-make

Environment:
   ADDICTION_DIR     : place to get addictions from (optional)
   BUILD_DIR         : place for build products and by-products (required)
   CRAFTINFO_PATH    : places to find craftinfos
   DEPENDENCY_DIR    : place to put dependencies into
EOF
  exit 1
}

#
# if only one configuration is chosen, make it the default
# if there are multiple configurations, make Release the default
# if Release is not in multiple configurations, then there is no default
#
r_determine_build_subdir()
{
   log_entry "r_determine_build_subdir" "$@"

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
      RVAL="/${configuration}"
   else
      RVAL="/${configuration}-${sdk}"
   fi
}


r_determine_dependencies_subdir()
{
   log_entry "r_determine_dependencies_subdir" "$@"

   local configuration="$1"
   local sdk="$2"
   local style="$3"

   [ -z "${configuration}" ] && internal_fail "configuration must not be empty"
   [ -z "${sdk}" ]           && internal_fail "sdk must not be empty"
   [ -z "${SDKS}" ]          && internal_fail "SDKS must not be empty"

   sdk="`LC_ALL=C "${SED:-sed}" 's/^\([a-zA-Z]*\).*$/\1/g' <<< "${sdk}" `"

   #
   # default style is none, as it its the easiest and least error
   # prone. Renamed from MULLE_DISPENSE_STYLE.
   #
   if [ -z "${style}" ]
   then
      style="${MULLE_CRAFT_DISPENSE_STYLE:-none}"
   fi

   if [ "${style}" = "auto" ]
   then
      style="configuration"

      n_sdks="`echo "${SDKS}" | wc -l | awk '{ print $1 }'`"
      if [ $n_sdks -gt 1 ]
      then
         style="configuration-sdk"
      fi
   fi

   RVAL=""
   case "${style}" in
      "none")
      ;;

      "configuration-strict")
         RVAL="/${configuration}"
      ;;

      "configuration-sdk-strict")
         RVAL="/${configuration}-${sdk}"
      ;;

      "configuration-sdk")
         if [ "${sdk}" = "Default" ]
         then
            if [ "${configuration}" != "Release" ]
            then
               RVAL="/${configuration}"
            fi
         else
            RVAL="/${configuration}-${sdk}"
         fi
      ;;

      "configuration")
         if [ "${configuration}" != "Release" ]
         then
            RVAL="/${configuration}"
         fi
      ;;

      *)
         fail "unknown value \"${style}\" for dispense style"
      ;;
   esac
}


#
# remove any non-identifiers and file extension from name
#
build_directory_name()
{
   log_entry "build_directory_name" "$@"

   local name="$1"

   tr -c 'a-zA-Z0-9-' '_' <<< "${name%.*}" | sed -e 's/_$//g'
}

# sets
#   _includepath
#   _frameworkspath
#   _libpath
#   _binpath
#
__set_various_paths()
{
   local configuration="$1"
   local sdk="$2"

   local RVAL

   _binpath="${PATH}"

   if [ ! -z "${ADDICTION_DIR}" ]
   then
      if [ -d "${ADDICTION_DIR}/include" ]
      then
         r_colon_concat "${_includepath}" "${ADDICTION_DIR}/include"
         _includepath="${RVAL}"
      fi

      if [ -d "${ADDICTION_DIR}/lib" ]
      then
         r_colon_concat "${_libpath}" "${ADDICTION_DIR}/lib"
         _libpath="${RVAL}"
      fi

      if [ -d "${ADDICTION_DIR}/bin" ]
      then
         r_colon_concat "${ADDICTION_DIR}/bin" "${_binpath}"
         _binpath="${RVAL}"
      fi
   fi

   if [ -d "${DEPENDENCY_DIR}/bin" ]
   then
      r_colon_concat "${DEPENDENCY_DIR}/bin" "${_binpath}"
      _binpath="${RVAL}"
   fi

   if [ -d "${DEPENDENCY_DIR}/${configuration}/bin" ]
   then
      r_colon_concat "${DEPENDENCY_DIR}/${configuration}/bin" "${_binpath}"
      _binpath="${RVAL}"
   fi
}


build_project()
{
   log_entry "build_project" "$@"

   local cmd="$1"
   local destination="$2"

   shift 2

   local project="$1";
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

   #
   # locate proper craftinfo path
   # searchpath:
   #
   # dependencies/share/mulle-craftinfo/<name>.txt
   # <project>/.mulle-craftinfo
   #
   local directory

   directory="`build_directory_name "${name}" `"

   #
   # find proper build directory
   # find proper log directory
   #
   local buildparentdir

   buildparentdir="${builddir}"

   r_filepath_concat "${buildparentdir}" "${directory}"
   builddir="${RVAL}"

   #
   # if projects exist with duplicate names, add a random number at end
   # to differentiate
   #
   local randomstring
   local oldproject

   case ",${marks}," in
      *,no-memo,*)
         # usally a subproject
      ;;

      *)
         #
         # allow name dupes, but try to avoid proliferation of
         # builddirs
         #
         if [ -d "${builddir}" ]
         then
            oldproject="`cat "${builddir}/.project" 2> /dev/null`"
            if [ ! -z "${oldproject}" -a "${oldproject}" != "${project}" ]
            then
               while [ -d "${builddir}" ]
               do
                  randomstring="`uuidgen | cut -c'1-6'`"
                  r_filepath_concat "${buildparentdir}" "${directory}-${randomstring}"
                  builddir="${RVAL}"
               done
            fi
         fi
      ;;
   esac

   mkdir_if_missing "${builddir}" || fail "Could not create build directory"

   # memo project to avoid clobbering builddirs
   redirect_exekutor "${builddir}/.project" echo "${project}"

   local logdir
   local craftinfodir

   r_filepath_concat "${builddir}" ".log"
   logdir="${RVAL}"

   r_determine_craftinfo_dir "${name}" \
                             "${project}" \
                             "dependency" \
                             "${OPTION_PLATFORM}" \
                             "${OPTION_LOCAL}" \
                             "${configuration}"
   case $? in
      0|2)
      ;;

      *)
         exit 1
      ;;
   esac
   craftinfodir="${RVAL}"

   # subdir for configuration / sdk

   local _includepath
   local _frameworkspath
   local _libpath
   local _binpath

   if [ ! -z "${DEPENDENCY_DIR}" ]
   then
      r_dependencies_include_path "${configuration}" "${sdk}"
      _includepath="${RVAL}"

      r_dependencies_lib_path "${configuration}" "${sdk}"
      _libpath="${RVAL}"

      case "${MULLE_UNAME}" in
         darwin)
            r_dependencies_frameworks_path "${configuration}" "${sdk}"
            _frameworkspath="${RVAL}"
         ;;
      esac
   fi

   __set_various_paths "${configuration}" "${sdk}"

   #
   # call mulle-make with all we've got now
   #
   local args

   args="${OPTIONS_MULLE_MAKE}"

   if [ ! -z "${name}" ]
   then
      r_concat "${args}" "--name '${name}'"
      args="${RVAL}"
   fi
   if [ ! -z "${logdir}" ]
   then
      r_concat "${args}" "--log-dir '${logdir}'"
      args="${RVAL}"
   fi
   if [ ! -z "${builddir}" ]
   then
      r_concat "${args}" "--build-dir '${builddir}'"
      args="${RVAL}"
   fi
   if [ ! -z "${craftinfodir}" ]
   then
      r_concat "${args}" "--info-dir '${craftinfodir}'"
      args="${RVAL}"
   else
      r_concat "${args}" "--info-dir 'NONE'"
      args="${RVAL}"
   fi
   if [ ! -z "${configuration}" ]
   then
      r_concat "${args}" "--configuration '${configuration}'"
      args="${RVAL}"
   fi
   if [ ! -z "${sdk}" ]
   then
      r_concat "${args}" "--sdk '${sdk}'"
      args="${RVAL}"
   fi
   if [ "${_binpath}" != "${PATH}" ]
   then
      r_concat "${args}" "--path '${_binpath}'"
      args="${RVAL}"
   fi
   if [ ! -z "${_includepath}" ]
   then
      r_concat "${args}" "--include-path '${_includepath}'"
      args="${RVAL}"
   fi
   if [ ! -z "${_libpath}" ]
   then
      r_concat "${args}" "--lib-path '${_libpath}'"
      args="${RVAL}"
   fi
   if [ ! -z "${_frameworkspath}" ]
   then
      r_concat "${args}" "--frameworks-path '${_frameworkspath}'"
      args="${RVAL}"
   fi
   if [ ! -z "${destination}" ]
   then
      r_concat "${args}" "--prefix '${destination}'"
      args="${RVAL}"
   fi
   if [ "${OPTION_ALLOW_SCRIPT}" = "YES" ]
   then
      r_concat "${args}" "--allow-script"
      args="${RVAL}"
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

   log_debug "args=${args}"
   log_debug "auxargs=${auxargs}"

   eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" \
                    "${cmd}" \
                       "${args}" \
                       "${auxargs}" \
                       "${project}" \
                       "${destination}"
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

   if [ $rval -ne 0 ]
   then
      return $rval
   fi

   local stylesubdir
   local options

   # ugliness for zlib
   case ",${marks}," in
      *',no-rootheader,'*)
         options="--header-dir include/${name}"
      ;;
   esac

   local RVAL

   r_determine_dependencies_subdir "${configuration}" "${sdk}"
   stylesubdir="${RVAL}"

   #
   # changed styles, it could lead to problems
   #
   if [ -z "${RVAL}" -a -d "${DEPENDENCY_DIR}/Debug" ]
   then
      log_warning "There is still an old Debug folder in dependency, which might cause trouble"
   fi

   dependencies_begin_update &&
   exekutor "${MULLE_DISPENSE}" \
               ${MULLE_TECHNICAL_FLAGS} \
               ${MULLE_DISPENSE_FLAGS} \
                 'dispense' \
                     ${options} \
                     "${DEPENDENCY_DIR}.tmp" \
                     "${DEPENDENCY_DIR}${stylesubdir}" &&
   dependencies_end_update
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
      *',no-dispense,'*)
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
      *',no-require,'*) # |*",no-require-${MULLE_UNAME},"*)
         if [ ! -d "${project}" ]
         then
            log_verbose "\"${project}\" does not exist, but it's not required"
            return 2
         fi
      ;;
   esac

   case ",${marks}," in
      *',no-dependency,'*)
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

      *',only-os-'*','*|*",no-os-${MULLE_UNAME},"*)
         fail "The buildorder ${C_RESET_BOLD}${BUILDORDER_FILE#${MULLE_USER_PWD}/}${C_ERROR} was made for a different platform. Time to clean. "
      ;;
   esac

   log_verbose "Build ${C_MAGENTA}${C_BOLD}${project}${C_VERBOSE}"

   build_dependency "install" "$@"
}


_do_build_buildorder()
{
   local buildorder="$1"; shift
   local builddir="$1"; shift
   local configuration="$1"; shift
   local sdk="$1"; shift

   local donefile

   mkdir_if_missing "${builddir}"

   donefile="${builddir}/${configuration}/.mulle-craft-built"

   local remaining

   remaining="${buildorder}"
   if [ ! -z "${donefile}" ]
   then
      if [ -f "${donefile}" ]
      then
         if [ "${OPTION_REBUILD_BUILDORDER}" = "YES" ]
         then
            remove_file_if_present "${donefile}"
         else
            remaining="`fgrep -x -v -f "${donefile}" <<< "${buildorder}"`"
            if [ -z "${remaining}" ]
            then
               log_fluff "Everything in the buildorder has been built already"
               return
            fi
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

      if [ -z "${MULLE_CASE_SH}" ]
      then
         . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-case.sh" || exit 1
      fi

      local base_identifier
      local RVAL

      r_tweaked_de_camel_case "${name}"
      base_identifier="`tr 'a-z-' 'A-Z_' <<< "${RVAL}" | tr -d -c 'A-Z_' `"

      #
      # Map some configurations (e.g. Debug -> Release for mulle-objc-runtime)
      # You can also map to empty, to skip a configuration
      #
      local identifier
      local value
      local mapped
      local escaped
      local mapped_configuration
      local RVAL

      identifier="${base_identifier}_MAP_CONFIGURATIONS"
      value="`eval echo \\\$${identifier}`"

      log_debug "${identifier}=\"${value}\" ($configuration)"

      mapped_configuration="${configuration}"

      if [ ! -z "${value}" ]
      then
         case ",${value}," in
            *",${configuration}->"*","*)
               r_escaped_sed_pattern "${configuration}"
               escaped="${RVAL}"
               mapped="`LC_ALL=C sed -n -e "s/.*,${escaped}->\([^,]*\),.*/\\1/p" <<< ",${value},"`"
               if [ -z "${mapped}" ]
               then
                  log_verbose "Configuration \"${configuration}\" skipped due to \"${identifier}\""
                  continue
               fi

               log_verbose "Configuration \"${configuration}\" mapped to \"${mapped}\" due to environment variable \"${identifier}\""
               mapped_configuration="${mapped}"
            ;;
         esac
      fi

      local subdir
      local mapped_builddir
      local RVAL

      r_determine_build_subdir "${mapped_configuration}" "${sdk}"
      subdir="${RVAL}"

      r_filepath_concat "${builddir}" "${subdir}"
      mapped_builddir="${RVAL}"

      build_buildorder_node "${evaledproject}" \
                            "${name}" \
                            "${marks}" \
                            "${mapped_builddir}" \
                            "${mapped_configuration}" \
                            "${sdk}" \
                            "$@"
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

   local buildorderfile="$1"; shift
   local builddir="$1"; shift

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

   local configurations
   local sdks

   configurations="${CONFIGURATIONS}"
   sdks="${SDKS}"

   # patch this with environment variables ?

   local configuration
   local sdk

   set -f; IFS=","
   for configuration in ${configurations}
   do
      for sdk in ${sdks}
      do
         set +f; IFS="${DEFAULT_IFS}"

         if ! _do_build_buildorder "${buildorder}" \
                                   "${builddir}"\
                                   "${configuration}" \
                                   "${sdk}" \
                                   "$@"
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

   local craftinfodir
   local name
   local RVAL

   name="${PROJECT_NAME}"
   if [ -z "${PROJECT_NAME}" ]
   then
      r_fast_basename "${PWD}"
      name="${RVAL}"
   fi

   log_verbose "Craft main project ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE}"

   r_determine_craftinfo_dir "${name}" \
                             "${PWD}" \
                             "mainproject" \
                             "${OPTION_PLATFORM}" \
                             "${OPTION_LOCAL}" \
                             "${CONFIGURATIONS%%,*}"
   craftinfodir="${RVAL}"

   # always set --info-dir
   if [ ! -z "${craftinfodir}" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--info-dir '${craftinfodir}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   else
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--info-dir 'NONE'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi

   local stylesubdir

   r_determine_build_subdir "${CONFIGURATIONS}" "${SDKS}"
   stylesubdir="${RVAL}"

   #
   # find proper build directory
   # find proper log directory
   #
   local builddir
   local logdir

   builddir="${BUILD_DIR}"
   r_filepath_concat "${builddir}" "${stylesubdir}"
   builddir="${RVAL}"
   r_filepath_concat "${builddir}" ".log"
   logdir="${RVAL}"

   [ $? -eq 1 ] && exit 1

   if [ ! -z "${PROJECT_LANGUAGE}" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--language '${PROJECT_LANGUAGE}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi

   r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--build-dir '${builddir}'"
   OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--log-dir '${logdir}'"
   OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"

   # ugly hackage
   if [ ! -z "${CONFIGURATIONS}" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--configuration '${CONFIGURATIONS%%,*}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi
   if [ ! -z "${SDKS}" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--sdk '${SDKS%%,*}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi
   if [ "${OPTION_ALLOW_SCRIPT}" = "YES" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--allow-script"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
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

   # never install the project, use mulle-make for that
   if ! eval_exekutor "'${MULLE_MAKE}'" "${MULLE_MAKE_FLAGS}" \
                        "build" "${OPTIONS_MULLE_MAKE_PROJECT}" "${auxargs}"
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
   local OPTION_PLATFORM="YES"
   local OPTION_LOCAL="YES"
   local OPTION_REBUILD_BUILDORDER="NO"
   local OPTION_PROTECT_DEPENDENCY="YES"
   local OPTION_ALLOW_SCRIPT="DEFAULT"

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
         --allow-script)
            OPTION_ALLOW_SCRIPT="YES"
         ;;

         --no-allow-script)
            OPTION_ALLOW_SCRIPT="NO"
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

         --protect)
            OPTION_PROTECT_DEPENDENCY="YES"
         ;;

         --no-protect)
            OPTION_PROTECT_DEPENDENCY="NO"
         ;;

         --rebuild)
            OPTION_REBUILD_BUILDORDER="YES"
         ;;

         --no-rebuild)
            OPTION_REBUILD_BUILDORDER="NO"
         ;;

         --debug)
            CONFIGURATIONS="Debug"
         ;;

         --release)
            CONFIGURATIONS="Release"
         ;;

         --no-platform|--no-platform-craftinfo)
            OPTION_PLATFORM="NO"
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL="NO"
         ;;

         --sdk)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            SDKS="$1"
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

   r_absolutepath "${BUILD_DIR}"
   BUILD_DIR="${RVAL}"
   if [ ! -z "${ADDICTION_DIR}" ]
   then
      r_absolutepath "${ADDICTION_DIR}"
      ADDICTION_DIR="${RVAL}"
   fi
   if [ ! -z "${DEPENDENCY_DIR}" ]
   then
      r_absolutepath "${DEPENDENCY_DIR}"
      DEPENDENCY_DIR="${RVAL}"
   fi
   if [ ! -z "${CRAFTINFO_PATH}" ]
   then
      r_absolutepath "${CRAFTINFO_PATH}"
      CRAFTINFO_PATH="${RVAL}"
   fi

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
      local RVAL

      builddir="${OPTION_BUILDORDER_BUILD_DIR:-${BUILD_DIR}}"
      r_filepath_concat "${builddir}" "${OPTION_SUBDIR}"
      builddir="${RVAL}"
      do_build_buildorder "${BUILDORDER_FILE}" "${builddir}" "$@"
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

