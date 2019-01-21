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
   ${MULLE_USAGE_NAME} ${USAGE_BUILD_STYLE} [options]

   ${USAGE_INFO}

Options:
   --all         : rebuild everything (doesn't clean)
   --debug       : compile for debug only
   --lenient     : do not stop on errors
   --no-protect  : do not make dependency read-only
   --release     : compile for release only
   --sdk <sdk>   : specify sdk to build against
   --            : pass remaining options to mulle-make

Environment:
   ADDICTION_DIR           : place to get addictions from (optional)
   BUILD_DIR               : place for build products (required)
   CRAFTINFO_PATH          : places to find craftinfos
   DEPENDENCY_DIR          : place to put dependencies into
   DEPENDENCY_TARBALL_PATH : tarballs to preinstall into dependency
   MULLE_SDE_MAKE_FLAGS    : additional flags passed to mulle-make
   MULLE_SDE_USE_SCRIPT    : enables building with scripts
EOF
  exit 1
}

#
# if only one configuration is chosen, make it the default
# if there are multiple configurations, make Release the default
# if Release is not in multiple configurations, then there is no default
#
r_determine_build_style_subdir()
{
   log_entry "r_determine_build_style_subdir" "$@"

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


r_determine_dependency_subdir()
{
   log_entry "r_determine_dependency_subdir" "$@"

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

   r_fast_basename "${name}"
   tr -c 'a-zA-Z0-9-' '_' <<< "${RVAL%.*}" | sed -e 's/_$//g'
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


r_effective_project_builddir()
{
   log_entry "r_effective_project_builddir" "$@"

   local name="$1"
   local buildparentdir="$2"

   local directory

   directory="`build_directory_name "${name}" `"

   #
   # find proper build directory
   # find proper log directory
   #
   local builddir

   r_filepath_concat "${buildparentdir}" "${directory}"
   builddir="${RVAL}"

   r_absolutepath "${builddir}"
   builddir="${RVAL}"

   #
   # allow name dupes, but try to avoid proliferation of
   # builddirs
   #
   if [ -d "${builddir}" ]
   then
      local oldproject

      oldproject="`cat "${builddir}/.project" 2> /dev/null`"
      if [ ! -z "${oldproject}" -a "${oldproject}" = "${project}" ]
      then
         RVAL="${builddir}"
         return 0
      fi

      #
      # if projects exist with duplicate names, add a random number at end
      # to differentiate
      #
      local randomstring

      while [ -d "${builddir}" ]
      do
         randomstring="`uuidgen | cut -c'1-6'`"
         r_filepath_concat "${buildparentdir}" "${directory}-${randomstring}"
         builddir="${RVAL}"
      done
   fi

   mkdir_if_missing "${builddir}" || fail "Could not create build directory"

   # memo project to avoid clobbering builddirs
   redirect_exekutor "${builddir}/.project" echo "${project}" || \
      fail "Could not write into ${builddir}"

   log_fluff "Build directory is \"${builddir}\""

   RVAL="${builddir}"
   return 0
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
   # if projects exist with duplicate names, add a random number at end
   # to differentiate
   #

   local flags

   case ",${marks}," in
      *,no-memo,*)
         # usally a subproject
         flags="${OPTION_NO_MEMO_MAKEFLAGS}"
      ;;
   esac

   local craftinfodir

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

   # remove old logs
   local logdir

   r_filepath_concat "${builddir}" ".log"
   logdir="${RVAL}"

   rmdir_safer "${logdir}"

   # subdir for configuration / sdk

   local _includepath
   local _frameworkspath
   local _libpath
   local _binpath

   if [ ! -z "${DEPENDENCY_DIR}" ]
   then
      r_dependency_include_path "${configuration}" "${sdk}"
      _includepath="${RVAL}"

      r_dependency_lib_path "${configuration}" "${sdk}"
      _libpath="${RVAL}"

      case "${MULLE_UNAME}" in
         darwin)
            r_dependency_frameworks_path "${configuration}" "${sdk}"
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

   case ",${marks}," in
      *',only-standalone,'*)
         r_concat "${args}" "-DSTANDALONE=ON"
         args="${RVAL}"
      ;;

      *',no-static-link,'*)
         r_concat "${args}" "-DBUILD_SHARED_LIBS=ON"
         args="${RVAL}"
         case "*,${marks},*" in
            *',no-all-load,'*)
            ;;

            *)
               log_verbose "Project \"${project}\" is marked as \"no-static-link\" \
and \"all-load\".
This can lead to problems on darwin, but may solve problems on linux..."
            ;;
         esac
      ;;

      *',no-dynamic-link,'*)
         r_concat "${args}" "-DBUILD_STATIC_LIBS=ON"
         args="${RVAL}"
      ;;
   esac

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
      r_concat "${args}" "--definition-dir '${craftinfodir}'"
      args="${RVAL}"
   else
      r_concat "${args}" "--definition-dir 'NONE'"
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

   if [ "${OPTION_ALLOW_SCRIPT}" = 'YES' ]
   then
      r_concat "${args}" "--allow-script"
      args="${RVAL}"
   fi

   if [ "${cmd}" != "install" ]
   then
      destination=""
   fi

   local mulle_flags_env_key
   local mulle_flags_env_value

   r_tweaked_de_camel_case "${name}"
   mulle_flags_env_key="MULLE_CRAFT_${RVAL}_MAKE_FLAGS"
   mulle_flags_env_key="`printf "%s" "${mulle_flags_env_key}" | tr -c 'a-zA-Z0-9' '_'`"
   mulle_flags_env_key="`tr 'a-z' 'A-Z' <<< "${mulle_flags_env_key}"`"
   mulle_flags_env_value="`eval echo "\\\$$mulle_flags_env_key"`"

   local auxargs
   local i

   if [ ! -z "${mulle_flags_env_value}" ]
   then
      log_verbose "Found ${C_RESET_BOLD}${mulle_flags_env_key}${C_VERBOSE} \
set to ${C_RESET_BOLD}${mulle_flags_env_value}${C_VERBOSE}"

      for i in ${mulle_flags_env_value}
      do
         r_concat "${auxargs}" "'${i}'"
         auxargs="${RVAL}"
      done
   else
      log_fluff "Environment variable ${mulle_flags_env_key} is not set."
   fi

   for i in "$@"
   do
      r_concat "${auxargs}" "'${i}'"
      auxargs="${RVAL}"
   done

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "flags:                 ${flags}"
      log_trace2 "MULLE_TECHNICAL_FLAGS: ${MULLE_TECHNICAL_FLAGS}"
      log_trace2 "MULLE_MAKE_FLAGS:      ${MULLE_MAKE_FLAGS}"
      log_trace2 "args:                  ${args}"
      log_trace2 "auxargs:               ${auxargs}"
      log_trace2 "mulle_flags_env_key:   ${mulle_flags_env_key}"
      log_trace2 "mulle_flags_env_value: ${mulle_flags_env_value}"
   fi

   eval_exekutor "'${MULLE_MAKE}'" \
                        "${flags}" \
                        "${MULLE_TECHNICAL_FLAGS}" \
                        "${MULLE_MAKE_FLAGS}" \
                    "${cmd}" \
                       "${args}" \
                       "${auxargs}" \
                       "${project}" \
                       "${destination}"
   rval=$?

   if [ ${rval} -ne 0 ]
   then
      log_fluff "Build of \"${project}\" failed ($rval)"
   fi

   return $rval
}


build_dependency_directly()
{
   log_entry "build_dependency_directly" "$@"

   local cmd="$1"; shift

   local project="$1"
   local name="$2"
   local marks="$3"
   local builddir="$4"
   local configuration="$5"
   local sdk="$6"

   if [ -z "${PARALLEL}" ]
   then
      dependency_begin_update || return 1
   fi

   local rval
   build_project "${cmd}" "${DEPENDENCY_DIR}" "$@"
   rval=$?


   if [ $rval -ne 0 ]
   then
      if [ "${OPTION_LENIENT}" = 'NO' ]
      then
         return 1
      fi
      rval=1
   fi


   if [ -z "${PARALLEL}" ]
   then
      if [ $rval != 1 ]
      then
         dependency_end_update || return 1
      fi
   fi

   # signal failures downward, even if lenient
   return $rval
}


build_dependency_with_dispense()
{
   log_entry "build_dependency_with_dispense" "$@"

   local cmd="$1"; shift

   local project="$1"
   local name="$2"
   local marks="$3"
   local builddir="$4"
   local configuration="$5"
   local sdk="$6"

   local rval

   rval=0

   local tmpdependencydir

   r_filepath_concat "${builddir}" ".dependency"
   r_absolutepath "${RVAL}"
   tmpdependencydir="${RVAL}"

   mkdir_if_missing "${tmpdependencydir}"

   build_project "${cmd}" "${tmpdependencydir}" "$@"
   rval=$?

   if [ "${cmd}" != 'install' -o $rval -ne 0 ]
   then
      rmdir_safer "${tmpdependencydir}"
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

   r_determine_dependency_subdir "${configuration}" "${sdk}"
   stylesubdir="${RVAL}"

   #
   # changed styles, it could lead to problems
   #
   if [ -z "${RVAL}" -a -d "${DEPENDENCY_DIR}/Debug" ]
   then
      log_warning "There is still an old Debug folder in dependency, which \
might cause trouble"
   fi

   case "${PARALLEL}" in
      "")
         dependency_begin_update || return 1
      ;;

      Headers)
         r_concat "${options}" --only-headers
         options="${RVAL}"
      ;;

      Link)
         r_concat "${options}" --no-headers
         options="${RVAL}"
      ;;
   esac

   exekutor "${MULLE_DISPENSE:-mulle-dispense}" \
                  ${MULLE_TECHNICAL_FLAGS} \
                  ${MULLE_DISPENSE_FLAGS} \
               dispense \
                  ${options} \
                  "${tmpdependencydir}" \
                  "${DEPENDENCY_DIR}${stylesubdir}"
   rval=$?

   rmdir_safer "${tmpdependencydir}"

   if [ -z "${PARALLEL}" ]
   then
      if [ $rval != 1 ]
      then
         dependency_end_update || return 1
      fi
   fi

   return $rval
}


#
# non-dependencies are build with their own BUILD_DIR
# not in the shared one.
#
build_buildorder_node()
{
   log_entry "build_buildorder_node" "$@"

   local cmd="$1"; shift

   local project="$1"
   local name="$2"
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
         internal_fail "Why are no-dependency nodes given ?"
      ;;

      *)
         if [ "${OPTION_BUILD_DEPENDENCY}" = 'NO' ]
         then
            log_fluff "Not building dependency \"${project}\" (complying with \
user wish)"
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
         fail "The buildorder ${C_RESET_BOLD}${BUILDORDER_FILE#${MULLE_USER_PWD}/}\
${C_ERROR} was made for a different platform. Time to clean. "
      ;;
   esac

   log_verbose "Build ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE}"

   case ",${marks}," in
      *',no-inplace,'*)
         build_dependency_with_dispense "${cmd}" "$@"
         return $?
      ;;
   esac

   build_dependency_directly "${cmd}" "$@"
   return $?
}


#
# uses passed in values to evaluate final ones
#
# local _builddir
# local _configuration
# local _evaledproject
# local _name
#
_evaluate_craft_variables()
{
   log_entry "_evaluate_craft_variables" "$@"

   local project="$1"
   local configuration="$2"
   local sdk="$3"
   local builddir="$4"

   local evaledproject
   local name

   #
   # getting the project name nice is fairly crucial to figure out when
   # things go wrong
   #
   _evaledproject="`eval echo "${project}"`"
   _name="${project#\$\{MULLE_SOURCETREE_STASH_DIR\}/}"
   if [ "${_name}" = "${project}" ]
   then
      _name="${_evaledproject#\$\{MULLE_VIRTUAL_ROOT\}/}"
   fi

   if [ -z "${MULLE_CASE_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-case.sh" || exit 1
   fi

   local base_identifier

   r_tweaked_de_camel_case "${_name}"
   base_identifier="`tr 'a-z-' 'A-Z_' <<< "${RVAL}" | tr -d -c 'A-Z0-9_' `"

   #
   # Map some configurations (e.g. Debug -> Release for mulle-objc-runtime)
   # You can also map to empty, to skip a configuration
   #
   local value
   local identifier

   identifier="MULLE_CRAFT_${base_identifier}_MAP_CONFIGURATIONS"
   value="`eval echo \\\$${identifier}`"

   _configuration="${configuration}"

   local mapped
   local escaped

   if [ ! -z "${value}" ]
   then
      case ",${value}," in
         *",${configuration}->"*","*)
            r_escaped_sed_pattern "${configuration}"
            escaped="${RVAL}"

            mapped="`LC_ALL=C sed -n -e "s/.*,${escaped}->\([^,]*\),.*/\\1/p" <<< ",${value},"`"
            if [ -z "${mapped}" ]
            then
               log_verbose "Configuration \"${configuration}\" skipped due \
to \"${identifier}\""
               return 0
            fi

            log_verbose "Configuration \"${configuration}\" mapped to \
\"${mapped}\" due to environment variable \"${identifier}\""
            _configuration="${mapped}"
         ;;
      esac
   fi

   r_determine_build_style_subdir "${configuration}" "${sdk}"
   r_filepath_concat "${builddir}" "${RVAL}"
   r_effective_project_builddir "${_name}" "${RVAL}"
   _builddir="${RVAL}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "${identifier}  : \"${value}\""
      log_trace2 "builddir       : \"${_builddir}\""
      log_trace2 "configuration  : \"${_configuration}\""
      log_trace2 "evaledproject  : \"${_evaledproject}\""
      log_trace2 "name           : \"${_name}\""
      log_trace2 "project        : \"${project}\""
      log_trace2 "sdk            : \"${sdk}\""
      log_trace2 "stylesubdir    : \"${stylesubdir}\""
   fi
}


handle_build()
{
   log_entry "handle_build" "$@"

   local cmd="$1"; shift

   local project="$1"; shift
   local marks="$1"; shift
   local configuration="$1"; shift
   local sdk="$1"; shift
   local builddir="$1"; shift

   local _name
   local _evaledproject
   local _builddir
   local _configuration

   _evaluate_craft_variables "${project}" "${configuration}" "${sdk}" "${builddir}"

   if [ "${OPTION_LIST_REMAINING}" = 'YES' ]
   then
      echo "${_name}" # ;${marks};${mapped_configuration}"
      return 0
   fi

   local rval

   build_buildorder_node "${cmd}" \
                         "${_evaledproject}" \
                         "${_name}" \
                         "${marks}" \
                         "${_builddir}" \
                         "${_configuration}" \
                         "${sdk}" \
                         "$@"
   rval=$?

   log_debug "${C_RESET_BOLD}Build finished with: ${C_MAGENTA}${C_BOLD}${rval}"

   return ${rval}
}


handle_build_rval()
{
   log_entry "handle_build_rval" "$@"

   local rval="$1"
   local marks="$2"
   local donefile="$3"
   local line="$4"
   local project="$5"

   if [ ${rval} -eq 0 ]
   then
      case ",${marks}," in
         *,no-memo,*)
            log_debug "Not remembering success due to no-memo"
            # usally a subproject
         ;;

         *)
            if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
            then
               log_trace2 "donefile   : ${donefile}"
               log_trace2 "line       : ${line}"
            fi

            if [ ! -z "${donefile}" ]
            then
               redirect_append_exekutor "${donefile}" echo "${line}"
            else
               log_debug "Not remembering success as we have no donefile"
            fi
         ;;
      esac
      return 0
   fi

   local evaledproject

   evaledproject="`eval echo "${project}"`"

   if [ ${rval} -eq 1 ]
   then
      if [ "${OPTION_LENIENT}" = 'NO' ]
      then
         log_debug "Build of \"${evaledproject}\" failed, so quit"
         return 1
      fi
         log_fluff "Ignoring build failure of \"${evaledproject}\" due to \
the enabled leniency option"
      return 0
   fi

   log_debug "Build of \"${evaledproject}\" returned ${rval}"
   return $rval
}



handle_build_step()
{
   log_entry "handle_build_step" "$@"

   local cmd="$1"; shift
   local project="$1"; shift
   local marks="$1"; shift
   local configuration="$1"; shift
   local sdk="$1"; shift
   local builddir="$1"; shift
   local phase="$1"; shift
   local statusfile="$1"; shift
   local line="$1"; shift
   local donefile="$1"; shift

   local rval

   handle_build "${cmd}" \
                "${project}" \
                "${marks}" \
                "${configuration}" \
                "${sdk}" \
                "${builddir}" \
                "--phase" "${phase}" \
                "$@"
   rval=$?

   local phasedonefile

   if [ "${phase}" = 'Link' ]
   then
      phasedonefile="${donefile}"
   fi

   if ! handle_build_rval "${rval}" \
                          "${marks}" \
                          "${phasedonefile}" \
                          "${line}" \
                          "${project}"
   then
      if [ $rval -ne 0 -a $rval -ne 2 ]
      then
         redirect_append_exekutor "${statusfile}" echo "${project};${phase};${rval}"
      fi
   fi
}


handle_parallel_builds()
{
   log_entry "handle_parallel_builds" "$@"

   local parallel="$1"; shift
   local donefile="$1"; shift

   local configuration="$1"; shift
   local sdk="$1"; shift
   local builddir="$1"; shift

   [ -z "${parallel}" ]      && internal_fail "v is empty"
   [ -z "${donefile}" ]      && internal_fail "donefile is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${sdk}" ]           && internal_fail "sdk is empty"
   [ -z "${builddir}" ]      && internal_fail "builddir is empty"

   local line
   local parallel
   local statusfile

   local phase
   local PARALLEL
   local cmd

   _r_make_tmp_in_dir "${BUILD_DIR}" ".build-status" "f"
   statusfile="${RVAL}"

   local parallel_link="NO"

   #
   # Check if we have something that can not be linked in parallel.
   # It's hard to detect, if the user set some "build shared libs" flag though.
   # So it must be allowed by the commandline too. In that case the
   # DependenciesAndLibraries.cmake must not be read, since we are just linking
   # a static library.
   #
   if [ "${parallel_link}" = 'YES' ]
   then
      # look for a line not having no-singlephase-link
      if egrep -v -s '[;,]no-singlephase-link[;,]|[;,]no-singlephase-link$' <<< "${parallel}"
      then
         log_fluff "Not all parallel builds are marked as no-singlephase-link, use sequential link"
         parallel_link='NO'
      else
         log_fluff "All parallel builds can also be parallel linked"
      fi
   else
      log_fluff "Parallel linking is not enabled"
   fi

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "parallel : ${parallel}"
   fi

   set -f
   for phase in ${OPTION_PHASES}
   do
      log_verbose "Starting phase ${phase}"

      PARALLEL="${phase}"

      case "${phase}" in
         Headers)
            dependency_begin_update || return 1
            cmd='install'
         ;;

         Compile)
            cmd='build'
         ;;

         Link)
            cmd='install'
         ;;
      esac

      local project
      local marks

      set -f ; IFS="
"
      for line in ${parallel}
      do
         set +f ; IFS="${DEFAULT_IFS}"

         local project
         local marks

         IFS=";" read project marks <<< "${line}"

         if [ "${phase}" != 'Link' -o "${parallel_link}" = 'YES'  ]
         then
            (
               handle_build_step "${cmd}" \
                                 "${project}" \
                                 "${marks}" \
                                 "${configuration}" \
                                 "${sdk}" \
                                 "${builddir}" \
                                 "${phase}" \
                                 "${statusfile}" \
                                 "${line}" \
                                 "${donefile}" \
                                 "$@"
            ) &
         else
            handle_build_step "${cmd}" \
                              "${project}" \
                              "${marks}" \
                              "${configuration}" \
                              "${sdk}" \
                              "${builddir}" \
                              "${phase}" \
                              "${statusfile}" \
                              "${line}" \
                              "${donefile}" \
                              "$@"
         fi
      done

      set +f ; IFS="${DEFAULT_IFS}"

      # collect phases
      log_fluff "Waiting for phase ${phase} to complete"

      wait

      log_verbose "Phase ${phase} complete"

      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_trace2 "Return values: `cat "${statusfile}"`"
      fi

      local failures

      failures="`cat "${statusfile}"`"

      if [ ! -z "${failures}" ]
      then
         log_fluff "Errors detected in \"${statusfile}\": ${failures}"

         local line

         set -f; IFS="
"
         for line in ${failures}
         do
            project="${line%;*}"      # project;phase (remove ;rval)
            phase="${project#*;}"
            project="${project%;*}"
            log_error "Parallel build of \"${project}\" failed in phase \"${phase}\""
         done
         set +f; IFS="${DEFAULT_IFS}"

         remove_file_if_present "${statusfile}"

         return 1
      fi

      case "${phase}" in
         Link)
            dependency_end_update || return 1
         ;;
      esac
   done
   set +f

   remove_file_if_present "${statusfile}"

   return 0
}


r_remaining_buildorder_lines()
{
   log_entry "r_remaining_buildorder_lines" "$@"

   local buildorder="$1"
   local donefile="$2"

   local remaining

   remaining="${buildorder}"
   if [ ! -z "${OPTION_SINGLE_DEPENDENCY}" ]
   then
      local escaped

      r_escaped_grep_pattern "${OPTION_SINGLE_DEPENDENCY}"
      remaining="`egrep "^${RVAL};|\}/${RVAL};" <<< "${remaining}" `"
      log_debug "Filtered by name: ${remaining}"
      if [ -z "${remaining}" ]
      then
         fail "\"${OPTION_SINGLE_DEPENDENCY}\" is unknown in the buildorder"
      fi
   else
      if [ ! -z "${donefile}" ]
      then
         if [ -f "${donefile}" ]
         then
            if [ "${OPTION_REBUILD_BUILDORDER}" = 'YES' ]
            then
               remove_file_if_present "${donefile}"
            else
               remaining="`rexekutor fgrep -x -v -f "${donefile}" <<< "${remaining}"`"
               if [ -z "${remaining}" ]
               then
                  RVAL=""
                  return 1
               fi
            fi
         fi
      fi
   fi

   RVAL="${remaining}"
   return 0
}


_do_build_buildorder()
{
   log_entry "_do_build_buildorder" "$@"

   local buildorder="$1"; shift
   local builddir="$1"; shift
   local configuration="$1"; shift
   local sdk="$1"; shift

   local remaining
   local donefile

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "buildorder: ${buildorder}"
   fi

   donefile="${builddir}/${configuration}/.mulle-craft-built"
   if [ -f "${donefile}" ]
   then
      log_fluff "Donefile \"${donefile}\" is present"
      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_trace2 "donefile: `cat "${donefile}"`"
      fi
      if ! r_remaining_buildorder_lines "${buildorder}" "${donefile}"
      then
         log_fluff "Everything in the buildorder has been built already"
         return
      fi
      remaining="${RVAL}"
   else
      log_fluff "Donefile \"${donefile}\" is not present, build everything"
      remaining="${buildorder}"

      mkdir_if_missing "${builddir}/${configuration}"
   fi

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "remaining :  ${remaining}"
   fi


   local line
   local parallel

   set -f ; IFS="
"
   for line in ${remaining}
   do
      set +f ; IFS="${DEFAULT_IFS}"

      local project
      local marks

      IFS=";" read project marks <<< "${line}"

      if [ -z "${project}" ]
      then
         internal_fail "empty project fail"
      fi

      if [ "${OPTION_PARALLEL}" = 'YES' -a  \
           "${OPTION_LIST_REMAINING}" = 'NO' -a \
           -z "${OPTION_SINGLE_DEPENDENCY}" ]
      then
         case ",${marks}," in
            *,no-singlephase,*)
               r_add_line "${parallel}" "${line}"
               parallel="${RVAL}"
               log_fluff "Collected ${line} for parallel build"
               continue
            ;;
         esac
      fi

      if [ ! -z "${parallel}" ]
      then
         if ! handle_parallel_builds "${parallel}" \
                                     "${donefile}" \
                                     "${configuration}" \
                                     "${sdk}" \
                                     "${builddir}" \
                                     "$@"
         then
            return 1
         fi
         parallel=""

         log_fluff "Handle ${line} for serial build"
         # fall thru for single build now
      fi

      handle_build "install" \
                   "${project}" \
                   "${marks}" \
                   "${configuration}" \
                   "${sdk}" \
                   "${builddir}" \
                   "$@"
      rval=$?

      if ! handle_build_rval "$rval" \
                             "${marks}" \
                             "${donefile}" \
                             "${line}" \
                             "${evaledproject}"
      then
         log_error "Serial ${configuration} craft of ${project} failed"
         return 1
      fi

      if [ ! -z "${OPTION_SINGLE_DEPENDENCY}" ]
      then
         return $rval
      fi
   done
   set +f ; IFS="${DEFAULT_IFS}"

   # left over parallel
   if [ ! -z "${parallel}" ]
   then
      if ! handle_parallel_builds "${parallel}" \
                                  "${donefile}" \
                                  "${configuration}" \
                                  "${sdk}" \
                                  "${builddir}" \
                                  "$@"
      then
         return 1
      fi
   fi
   return 0
}


do_build_buildorder()
{
   log_entry "do_build_buildorder" "$@"

   local buildorderfile="$1"; shift
   local builddir="$1"; shift

   [ -z "${buildorderfile}" ] && internal_fail "buildorderfile is missing"
   [ -z "${builddir}" ] && internal_fail "builddir is missing"

   local buildorder

   buildorder="`egrep -v '^#' "${buildorderfile}" 2> /dev/null`"
   [ $? -eq 2 ] && fail "Buildorder file \"${buildorderfile}\" is missing"

   #
   # Do this once initially, even if there are no dependencies
   # That allows tarballs to be installed. Also now the existance of the
   # dependency folders, means something
   #
   dependency_begin_update 'warn' || exit 1

   if [ -z "${buildorder}" ]
   then
      dependency_end_update 'complete' || exit 1
      log_verbose "The buildorder file is empty, nothing to build \
(${buildorderfile#${MULLE_USER_PWD}/})"
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

   dependency_end_update 'complete' || exit 1
}



do_build_mainproject()
{
   log_entry "do_build_mainproject" "$@"

   local craftinfodir
   local name
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
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--definition-dir '${craftinfodir}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   else
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--definition-dir 'NONE'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi

   local stylesubdir

   r_determine_build_style_subdir "${CONFIGURATIONS}" "${SDKS}"
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

   # remove old logs
   rmdir_safer "${logdir}"

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
   if [ "${OPTION_ALLOW_SCRIPT}" = 'YES' ]
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
   if ! eval_exekutor "'${MULLE_MAKE}'" \
                           "${MULLE_TECHNICAL_FLAGS}" \
                           "${MULLE_MAKE_FLAGS}" \
                        "build" \
                           "${OPTIONS_MULLE_MAKE_PROJECT}" \
                           "${auxargs}"
   then
      log_fluff "Project build failed"
      return 1
   fi

   if [ "${MULLE_FLAG_MOTD}" = 'NO' ]
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
# mulle-craft isn't ruled so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde.
#
craft_build_common()
{
   log_entry "craft_build_common" "$@"

   local OPTION_LENIENT='NO'
   local OPTION_BUILD_DEPENDENCY="DEFAULT"
   local OPTIONS_MULLE_MAKE_PROJECT=
   local OPTION_PLATFORM='YES'
   local OPTION_LOCAL='YES'
   local OPTION_REBUILD_BUILDORDER='NO'
   local OPTION_PROTECT_DEPENDENCY='YES'
   local OPTION_ALLOW_SCRIPT="${MULLE_SDE_USE_SCRIPT:-DEFAULT}"
   local OPTION_SINGLE_DEPENDENCY
   local OPTION_LIST_REMAINING='NO'
   local OPTION_CLEAN_TMP='YES'
   local OPTION_PARALLEL_LINK='YES'
   local OPTION_PHASES="Headers Compile Link"
   local OPTION_PARALLEL='YES'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            build_execute_usage
         ;;

         -l|--lenient)
            OPTION_LENIENT='YES'
         ;;

         --all|--rebuild)
            OPTION_REBUILD_BUILDORDER='YES'
         ;;

         --no-rebuild)
            OPTION_REBUILD_BUILDORDER='NO'
         ;;

         --no-lenient)
            OPTION_LENIENT='NO'
         ;;

         --no-clean-tmp)
            OPTION_CLEAN_TMP='YES'
         ;;

         --no-memo-makeflags)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            OPTION_NO_MEMO_MAKEFLAGS="$1"  # could be global env
         ;;

         # these are dependency within buildorder, buildorder has also subproj
         --allow-script)
            OPTION_ALLOW_SCRIPT='YES'
         ;;

         --no-allow-script)
            OPTION_ALLOW_SCRIPT='NO'
         ;;

         --dependency)
            OPTION_BUILD_DEPENDENCY='YES'
         ;;

         --only-dependency)
            OPTION_BUILD_DEPENDENCY="ONLY"
         ;;

         --no-dependency)
            OPTION_BUILD_DEPENDENCY='NO'
         ;;

         --parallel)
            OPTION_PARALLEL='YES'
         ;;

         --no-parallel|--serial)
            OPTION_PARALLEL='NO'
         ;;

         --parallel-link)
            OPTION_PARALLEL_LINK='YES'
         ;;

         --no-parallel-link|--serial-link)
            OPTION_PARALLEL_LINK='NO'
         ;;

         --protect)
            OPTION_PROTECT_DEPENDENCY='YES'
         ;;

         --no-protect)
            OPTION_PROTECT_DEPENDENCY='NO'
         ;;

         --no-platform|--no-platform-craftinfo)
            OPTION_PLATFORM='NO'
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL='NO'
         ;;

         --list-remaining)
            OPTION_LIST_REMAINING='YES'
         ;;

         --single-dependency)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

				OPTION_SINGLE_DEPENDENCY="$1"
			;;

         #
         # config / sdk
         #
         --configuration)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            CONFIGURATIONS="$1"
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

         # pass remaining stuff to mulle-make
         --)
            shift
            break
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   if [ -z "${CONFIGURATIONS}" ]
   then
      CONFIGURATIONS="Debug"
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
   currentenv="${MULLE_UNAME};${MULLE_HOSTNAME};${LOGNAME:-`id -u 2>/dev/null`}"

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

   if [ "${OPTION_USE_BUILDORDER}" = 'YES' ]
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

      [ -z "${MULLE_CRAFT_DEPENDENCY_SH}" ] && \
         . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-dependency.sh"

      do_build_buildorder "${BUILDORDER_FILE}" "${BUILDORDER_BUILD_DIR}" "$@"
      return $?
   fi

   #
   # Build the project
   #
   [ "${OPTION_USE_PROJECT}" = 'YES' ] || internal_fail "hein ?"

   do_build_mainproject "$@"
}


build_project_main()
{
   log_entry "build_project_main" "$@"

   USAGE_BUILD_STYLE="project"
   USAGE_INFO="Build the project only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='YES'
   OPTION_USE_BUILDORDER='NO'
   OPTION_MUST_HAVE_BUILDORDER='NO'

   craft_build_common "$@"
}


build_buildorder_main()
{
   log_entry "build_buildorder_main" "$@"

   USAGE_BUILD_STYLE="buildorder"
   USAGE_INFO="Build the buildorder only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_BUILDORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft_build_common "$@"
}


list_buildorder_main()
{
   log_entry "list_buildorder_main" "$@"

   USAGE_BUILD_STYLE="list"
   USAGE_INFO="List remaining items in buildorder to be built.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_BUILDORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft_build_common --list-remaining "$@"
}


build_single_dependency_main()
{
   log_entry "build_single_dependency_main" "$@"

   local name="$1"; shift

   USAGE_BUILD_STYLE="buildorder --single-dependency '${name}'"
   USAGE_INFO="Build a single dependency of the buildorder only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_BUILDORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft_build_common --single-dependency "${name}" "$@"
}

