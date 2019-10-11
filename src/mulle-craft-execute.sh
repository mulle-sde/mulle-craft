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
   --all          : rebuild everything (doesn't clean)
   --debug        : compile for debug only
   --lenient      : do not stop on errors
   --no-protect   : do not make dependency read-only
   --release      : compile for release only
   --test         : compile for test only
   --sdk <sdk>    : specify sdk to build against (Default)
   --platform <p> : specify platform to build for (Default)
   --style <s>    : dependency style: auto, none, relax, strict, tight
   --             : pass remaining options to mulle-make

Environment:
   ADDICTION_DIR           : place to get addictions from (optional)
   KITCHEN_DIR             : place for intermediate craft products (required)
   CONFIGURATIONS          : configurations to build, ':' separated
   CRAFTINFO_PATH          : places to find craftinfos
   DISPENSE_STYLE          : how to place build products into dependency (none)
   DEPENDENCY_DIR          : place to put dependencies into
   DEPENDENCY_TARBALL_PATH : tarballs to preinstall into dependency
   MULLE_CRAFT_MAKE_FLAGS  : additional flags passed to mulle-make
   MULLE_CRAFT_USE_SCRIPT  : enables building with scripts
   PLATFORMS               : platforms to build, ':' separated
   SDKS                    : sdks to build, ':' separated

Styles:
   none    : use root only. Only useful for a single configuration/sdk/platform
   auto    : fold SDK/PLATFORM Default and CONFIGURATION Release to root
   relax   : fold SDK/PLATFORM Default but not CONFIGURATION Release
   strict  : differentiate according to SDK/PLATFORM/CONFIGURATION
   tight   : differentiate according to SDK/PLATFORM/CONFIGURATION flat

EOF
  exit 1
}



assert_sane_name()
{
   local name="$1"; shift

   if [ "`tr -d -c 'a-zA-Z0-9_.-' <<< "${name}" `" != "${name}" ]
   then
      fail "\"${name}\" contains invalid characters$*"
   fi
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
   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   _binpath="${PATH}"

   local sdk_platform

   r_get_sdk_platform_style_string "${sdk}" "${platform}" "${style}"
   sdk_platform="${RVAL}"

   if [ ! -z "${ADDICTION_DIR}" ]
   then
      if [ ! -z "${sdk_platform}" ]
      then
         if [ -d "${ADDICTION_DIR}/${sdk_platform}/include" ]
         then
            r_colon_concat "${_includepath}" "${ADDICTION_DIR}/${sdk_platform}/include"
            _includepath="${RVAL}"
         fi

         if [ -d "${ADDICTION_DIR}/${sdk_platform}/Frameworks" ]
         then
            r_colon_concat "${_frameworkspath}" "${ADDICTION_DIR}/${sdk_platform}/Frameworks"
            _frameworkspath="${RVAL}"
         fi

         if [ -d "${ADDICTION_DIR}/${sdk_platform}/lib" ]
         then
            r_colon_concat "${_libpath}" "${ADDICTION_DIR}/${sdk_platform}/lib"
            _libpath="${RVAL}"
         fi

         if [ -d "${ADDICTION_DIR}/${sdk_platform}/bin" ]
         then
            r_colon_concat "${ADDICTION_DIR}/${sdk_platform}/bin" "${_binpath}"
            _binpath="${RVAL}"
         fi
      fi

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

      if [ -d "${ADDICTION_DIR}/Frameworks" ]
      then
         r_colon_concat "${_frameworkspath}" "${ADDICTION_DIR}/Frameworks"
         _frameworkspath="${RVAL}"
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

   if [ ! -z "${sdk_platform}" ]
   then
      if [ -d "${DEPENDENCY_DIR}/${sdk_platform}/bin" ]
      then
         r_colon_concat "${DEPENDENCY_DIR}/${sdk_platform}/bin" "${_binpath}"
         _binpath="${RVAL}"
      fi

      if [ -d "${DEPENDENCY_DIR}/${sdk_platform}/${configuration}/bin" ]
      then
         r_colon_concat "${DEPENDENCY_DIR}/${sdk_platform}/${configuration}/bin" "${_binpath}"
         _binpath="${RVAL}"
      fi
   fi
}


r_effective_project_kitchendir()
{
   log_entry "r_effective_project_kitchendir" "$@"

   local name="$1"
   local parentkitchendir="$2"
   local verify="${3:-YES}"

   local directory

   # allow '*' for log, possibly foo* too
   case "${name}" in
      *'*')
         directory="${name}"
      ;;

      *)
         directory="`build_directory_name "${name}" `"
      ;;
   esac

   #
   # find proper build directory
   # find proper log directory
   #
   local kitchendir

   r_filepath_concat "${parentkitchendir}" "${directory}"
   kitchendir="${RVAL}"

   r_absolutepath "${kitchendir}"
   kitchendir="${RVAL}"

   #
   # allow name dupes, but try to avoid proliferation of
   # builddirs
   #
   if [ "${verify}" = 'YES' ] && [ -d "${kitchendir}" ]
   then
      local oldproject

      oldproject="`cat "${kitchendir}/.project" 2> /dev/null`"
      if [ ! -z "${oldproject}" -a "${oldproject}" = "${project}" ]
      then
         RVAL="${kitchendir}"
         return 0
      fi

      #
      # if projects exist with duplicate names, add a random number at end
      # to differentiate
      #
      local randomstring

      while [ -d "${kitchendir}" ]
      do
         randomstring="`uuidgen | cut -c'1-6'`"
         r_filepath_concat "${parentkitchendir}" "${directory}-${randomstring}"
         kitchendir="${RVAL}"
      done
   fi

   log_fluff "Kitchen directory is \"${kitchendir}\""

   RVAL="${kitchendir}"
   return 0
}


r_get_mulle_sdk_path()
{
   log_entry "r_get_mulle_sdk_path" "$@"

   local sdk="$1"
   local platform="$2"
   local style="$3"

   local sdk_platform

   r_get_sdk_platform_style_string "${sdk}" "${platform}" "${style}"
   sdk_platform="${RVAL}"

   local addiction_dir
   local dependency_dir

   r_filepath_concat "${ADDICTION_DIR}" "${sdk_platform}"
   addiction_dir="${RVAL}"
   r_filepath_concat "${DEPENDENCY_DIR}" "${sdk_platform}"
   dependency_dir="${RVAL}"

   r_colon_concat "${dependency_dir}" "${addiction_dir}"
   r_colon_concat "${RVAL}" "${MULLE_SDK_PATH}"

   log_debug "sdk_path: ${RVAL}"
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
   local kitchendir="$4"
   local sdk="$5"
   local platform="$6"
   local configuration="$7"
   local style="$8"

   shift 8

   [ -z "${cmd}" ]         && internal_fail "cmd is empty"
   [ -z "${destination}" ] && internal_fail "destination is empty"

   [ -z "${project}" ]     && internal_fail "project is empty"
   [ -z "${name}" ]        && internal_fail "name is empty"
   [ -z "${kitchendir}" ]  && internal_fail "kitchendir is empty"

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
                             "${OPTION_PLATFORM_CRAFTINFO}" \
                             "${OPTION_LOCAL_CRAFTINFO}" \
                             "${sdk}" \
                             "${platform}" \
                             "${configuration}" \
                             "${style}"
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

   r_filepath_concat "${kitchendir}" ".log"
   logdir="${RVAL}"

   rmdir_safer "${logdir}"

   # subdir for configuration / sdk

   local _includepath
   local _frameworkspath
   local _libpath
   local _binpath

   if [ ! -z "${DEPENDENCY_DIR}" ]
   then
      r_dependency_include_path  "${sdk}" "${platform}" "${configuration}" "${style}"
      _includepath="${RVAL}"

      r_dependency_lib_path "${sdk}" "${platform}" "${configuration}" "${style}"
      _libpath="${RVAL}"

      case "${MULLE_UNAME}" in
         darwin)
            r_dependency_frameworks_path "${sdk}" "${platform}" "${configuration}" "${style}"
            _frameworkspath="${RVAL}"
         ;;
      esac
   fi

   __set_various_paths "${sdk}" "${platform}" "${configuration}" "${style}"

   #
   # call mulle-make with all we've got now
   #
   local args

   args="${MULLE_CRAFT_MAKE_OPTIONS}"

   if [ ! -z "${name}" ]
   then
      r_concat "${args}" "--name '${name}'"
      args="${RVAL}"
   fi

   #
   # this is supposed to be a global override
   # it's probably superflous. You can tune options on a per-project
   # basis with marks and environment variables
   #
   if [ ! -z "${MULLE_CRAFT_LIBRARY_STYLE}" ]
   then
      case "${MULLE_CRAFT_LIBRARY_STYLE}" in
         standalone)
            r_concat "${args}" "--library-style standalone"
            args="${RVAL}"
         ;;

         dynamic|shared)
            r_concat "${args}" "--library-style shared"
            args="${RVAL}"
         ;;

         static)
            r_concat "${args}" "--library-style static"
            args="${RVAL}"
         ;;

         *)
            fail "Unknown library style \"${MULLE_CRAFT_LIBRARY_STYLE}\" (use dynamic/static/standalone)"
         ;;
      esac
   else
      case ",${marks}," in
         *',only-standalone,'*)
            r_concat "${args}" "--library-style standalone"
            args="${RVAL}"
         ;;

         *',no-static-link,'*)
            r_concat "${args}" "--library-style dynamic"
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
            r_concat "${args}" "--library-style static"
            args="${RVAL}"
         ;;
      esac
   fi

   if [ ! -z "${logdir}" ]
   then
      r_concat "${args}" "--log-dir '${logdir}'"
      args="${RVAL}"
   fi
   if [ ! -z "${kitchendir}" ]
   then
      r_concat "${args}" "--build-dir '${kitchendir}'"
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
   if [ ! -z "${platform}" ]
   then
      r_concat "${args}" "--platform '${platform}'"
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

   local sdk_path

   r_get_mulle_sdk_path "${sdk}" "${platform}" "auto"
   sdk_path="${RVAL}"

   if [ ! -z "${sdk_path}" ]
   then
      r_concat "${args}" "-DMULLE_SDK_PATH='${sdk_path}'"
      args="${RVAL}"
   fi

   if [ "${cmd}" != "install" ]
   then
      destination=""
   fi

   local mulle_options_env_key
   local mulle_options_env_value

   r_tweaked_de_camel_case "${name}"
   mulle_options_env_key="MULLE_CRAFT_${RVAL}_MAKE_OPTIONS"
   mulle_options_env_key="`printf "%s" "${mulle_options_env_key}" | tr -c 'a-zA-Z0-9' '_'`"
   mulle_options_env_key="`tr 'a-z' 'A-Z' <<< "${mulle_options_env_key}"`"
   mulle_options_env_value="`eval echo "\\\$$mulle_options_env_key"`"

   local auxargs
   local i

   if [ ! -z "${mulle_options_env_value}" ]
   then
      log_verbose "Found ${C_RESET_BOLD}${mulle_options_env_key}${C_VERBOSE} \
set to ${C_RESET_BOLD}${mulle_options_env_value}${C_VERBOSE}"

      for i in ${mulle_options_env_value}
      do
         r_concat "${auxargs}" "'${i}'"
         auxargs="${RVAL}"
      done
   else
      log_fluff "Environment variable ${mulle_options_env_key} is not set."
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


   eval_exekutor "${environment}" \
                     '${MULLE_MAKE}' \
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
   local dependency_dir="$1"; shift

#   local project="$1"
#   local name="$2"
#   local marks="$3"
#   local kitchendir="$4"
#   local sdk="$5"
#   local platform="$6"
#   local configuration="$7"
   local style="$8"

   if [ -z "${PARALLEL}" ]
   then
      dependency_begin_update "${style}" || return 1
   fi

   local rval

   build_project "${cmd}" "${dependency_dir}" "$@"
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
   local dependency_dir="$1"; shift

   local project="$1"
   local name="$2"
   local marks="$3"
   local kitchendir="$4"
   local sdk="$5"
   local platform="$6"
   local configuration="$7"
   local style="$8"

   local rval
   local tmpdependencydir

   r_filepath_concat "${kitchendir}" ".dependency"
   r_absolutepath "${RVAL}"
   tmpdependencydir="${RVAL}"

   mkdir_if_missing "${tmpdependencydir}"

   build_project "${cmd}" "${tmpdependencydir}" "$@"
   rval=$?

   if [ "${cmd}" != 'install' -o $rval -ne 0 ]
   then
      if [ $rval -ne 0 ]
      then
         log_verbose "Not dispensing because of non-zero exit"
      else
         log_verbose "Not dispensing because not installing"
      fi
      rmdir_safer "${tmpdependencydir}"
      return $rval
   fi

   local options

   # ugliness for zlib
   # not very good, because include is OS specific
   # need to late eval this
   case ",${marks}," in
      *',no-rootheader,'*)
         options="--header-dir 'include/${name}'"
      ;;
   esac

   case ",${marks}," in
      *',only-liftheaders,'*)
         options="--lift-headers"
      ;;
   esac

   case "${PARALLEL}" in
      "")
         dependency_begin_update "${style}" || return 1
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

   log_verbose "Dispensing product"

   eval_exekutor "${MULLE_DISPENSE:-mulle-dispense}" \
                  "${MULLE_TECHNICAL_FLAGS}" \
                  "${MULLE_DISPENSE_FLAGS}" \
               dispense \
                  "${options}" \
                  "${tmpdependencydir}" \
                  "${dependency_dir}"
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
# non-dependencies are build with their own KITCHEN_DIR
# not in the shared one.
#
build_craftorder_node()
{
   log_entry "build_craftorder_node" "$@"

   local cmd="$1"; shift

   local project="$1"
   local name="$2"
   local marks="$3"
#   local kitchendir="$4"
   local sdk="$5"
   local platform="$6"
   local configuration="$7"
   local style="$8"

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

   # the craftorder should have filtered these out already
   case ",${marks}," in
      *",only-os-${MULLE_UNAME}",*)
         # nice
      ;;

      *',only-os-'*','*|*",no-os-${MULLE_UNAME},"*)
         fail "The craftorder ${C_RESET_BOLD}${CRAFTORDER_FILE#${MULLE_USER_PWD}/}\
${C_ERROR} was made for a different platform. Time to clean. "
      ;;
   esac

   # the craftorder should have filtered these out already
   case ",${marks}," in
      *",only-build-sdk-"*)
         case ",${marks}," in
            *",only-build-sdk-${sdk},"*)
               # pass
            ;;

            *)
               log_fluff "Not building \"${project}\" due to \"only-build-sdk-${sdk}\" mark"
               return 2         # nice
            ;;
         esac
      ;;

      *",no-build-sdk-"*)
         case ",${marks}," in
            *",no-build-sdk-${sdk},"*)
               log_fluff "Not building \"${project}\" due to \"no-build-sdk-${sdk}\" mark"
               return 2         # nice
            ;;
         esac
      ;;
   esac

   #
   # Figure out where to dispense into
   #
   local dependency_dir

   r_get_sdk_platform_configuration_style_string "${sdk}" \
                                                 "${platform}" \
                                                 "${configuration}"  \
                                                 "${style}"
   r_filepath_concat "${DEPENDENCY_DIR}" "${RVAL}"
   dependency_dir="${RVAL}"

   #
   # Depending on marks, either install and dispense or just install
   #
   case ",${marks}," in
      *',no-inplace,'*)
         log_verbose "Build ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE} with dispense"
         build_dependency_with_dispense "${cmd}" "${dependency_dir}" "$@"
         return $?
      ;;
   esac

   log_verbose "Build ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE}"
   build_dependency_directly "${cmd}" "${dependency_dir}" "$@"
   return $?
}


r_name_from_evaledproject()
{
   local evaledproject="$1"

   [ -z "${evaledproject}" ] && internal_fail "evaledproject is empty"

   local name
#   log_trace2 "MULLE_VIRTUAL_ROOT=${MULLE_VIRTUAL_ROOT}"
#   log_trace2 "MULLE_SOURCETREE_STASH_DIR=${MULLE_SOURCETREE_STASH_DIR}"

   name="${evaledproject#${MULLE_VIRTUAL_ROOT:-${PWD}}/}"
   name="${name#${MULLE_SOURCETREE_STASH_DIR:-stash}/}"

   # replace everything thats not an identifier or . _ - + with -
   name="`tr -c 'A-Za-z0-9_.+-' '-' <<< "${name}" `"
   name="${name#-}"
   name="${name%-}"

   [ -z "${name}" ] && internal_fail "Name is empty from \"${project}\""
   RVAL="${name}"
}


r_name_from_project()
{
   local  project="$1"

   r_name_from_evaledproject "`eval "echo \"${project}\""`"
}


#
# uses passed in values to evaluate final ones. This code may change the
# configuration (f.e. a nice feature, if a project doesn't support it)
# and will finalize the name of the build directory and the name to be shown
# as what gets compiled.
#
# local _kitchendir
# local _configuration
# local _evaledproject
# local _name
#
_evaluate_craft_variables()
{
   log_entry "_evaluate_craft_variables" "$@"

   local project="$1"
   local sdk="$2"
   local platform="$3"
   local configuration="$4"
   local style="$5"
   local kitchendir="$6"
   local verify="$7"   # can be left empty

   #
   # getting the project name nice is fairly crucial to figure out when
   # things go wrong
   #
   if [ "${project}" = '*' ]
   then
      _name="${project}"
      _evaledproject=""
      log_fluff "Configuration mapping will not be found by logs"
   else
      _evaledproject="`eval "echo \"${project}\"" `"
      r_name_from_evaledproject "${_evaledproject}"
      _name="${RVAL}"

      local base_identifier

      if [ -z "${MULLE_CASE_SH}" ]
      then
        . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-case.sh" || exit 1
      fi

      r_tweaked_de_camel_case "${name}"
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
   fi

   #
   # this is the build style which is always "relax"
   #
   if [ -z "${MULLE_CRAFT_SEARCHPATH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-searchpath.sh" || exit 1
   fi

   r_get_sdk_platform_configuration_style_string "${sdk}" \
                                                 "${platform}" \
                                                 "${configuration}" \
                                                 "relax"
   r_filepath_concat "${kitchendir}" "${RVAL}"
   r_effective_project_kitchendir "${_name}" "${RVAL}" "${verify}"
   _kitchendir="${RVAL}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "kitchendir       : \"${_kitchendir}\""
      log_trace2 "configuration  : \"${_configuration}\""
      log_trace2 "evaledproject  : \"${_evaledproject}\""
      log_trace2 "name           : \"${_name}\""
   fi
}


handle_build()
{
   log_entry "handle_build" "$@"

   local cmd="$1"; shift

   local project="$1"; shift
   local marks="$1"; shift
   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local style="$1"; shift
   local kitchendir="$1"; shift

   local _name
   local _evaledproject
   local _kitchendir
   local _configuration

   #
   # get remapped _configuration
   # get actual _kitchendir
   #
   _evaluate_craft_variables "${project}" \
                             "${sdk}" \
                             "${platform}" \
                             "${configuration}" \
                             "${style}" \
                             "${kitchendir}"

   if [ "${OPTION_LIST_REMAINING}" = 'YES' ]
   then
      printf "%s\n" "${_name}" # ;${marks};${mapped_configuration}"
      return 0
   fi

   mkdir_if_missing "${_kitchendir}" || fail "Could not create build directory"

   # memo project to avoid clobbering builddirs
   redirect_exekutor "${_kitchendir}/.project" printf "%s\n" "${project}" || \
      fail "Could not write into ${_kitchendir}"

   local rval

   build_craftorder_node "${cmd}" \
                         "${_evaledproject}" \
                         "${_name}" \
                         "${marks}" \
                         "${_kitchendir}" \
                         "${sdk}" \
                         "${platform}" \
                         "${_configuration}" \
                         "${style}" \
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
               redirect_append_exekutor "${donefile}" printf "%s\n" "${line}"
            else
               log_debug "Not remembering success as we have no donefile"
            fi
         ;;
      esac
      return 0
   fi

   local evaledproject

   evaledproject="`eval "echo \"${project}\""`"

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

   # 2 is OK and we warned before
   if [ ${rval} -eq 2 ]
   then
      log_debug "Ignoring harmless failure"
      return 0
   fi

   log_debug "Build of \"${evaledproject}\" returned ${rval}"
   return 1
}



handle_build_step()
{
   log_entry "handle_build_step" "$@"

   local cmd="$1"; shift
   local project="$1"; shift
   local marks="$1"; shift
   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local style="$1"; shift
   local kitchendir="$1"; shift
   local phase="$1"; shift
   local statusfile="$1"; shift
   local line="$1"; shift
   local donefile="$1"; shift

   local rval

   handle_build "${cmd}" \
                "${project}" \
                "${marks}" \
                "${sdk}" \
                "${platform}" \
                "${configuration}" \
                "${style}" \
                "${kitchendir}" \
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
      redirect_append_exekutor "${statusfile}" printf "%s\n" "${project};${phase};${rval}"
   fi
}


handle_parallel_builds()
{
   log_entry "handle_parallel_builds" "$@"

   local parallel="$1"; shift
   local donefile="$1"; shift

   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local style="$1"; shift
   local kitchendir="$1"; shift

   [ -z "${parallel}" ]      && internal_fail "v is empty"
   [ -z "${donefile}" ]      && internal_fail "donefile is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${platform}" ]      && internal_fail "platform is empty"
   [ -z "${sdk}" ]           && internal_fail "sdk is empty"
   [ -z "${style}" ]         && internal_fail "style is empty"
   [ -z "${kitchendir}" ]      && internal_fail "kitchendir is empty"

   local line
   local parallel
   local statusfile

   local phase
   local PARALLEL
   local cmd

   _r_make_tmp_in_dir "${KITCHEN_DIR}" ".build-status" "f"
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
            dependency_begin_update "${style}" || return 1
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

      set -f ; IFS=$'\n'
      for line in ${parallel}
      do
         set +f ; IFS="${DEFAULT_IFS}"

         local project
         local marks

         IFS=";" read project marks <<< "${line}"

         #
         # TODO: we are somewhat overoptimistic, that we don't build
         #       1000 projects in parallel here and run into system
         #       limitations...
         #
         if [ "${phase}" != 'Link' -o "${parallel_link}" = 'YES'  ]
         then
            (
               handle_build_step "${cmd}" \
                                 "${project}" \
                                 "${marks}" \
                                 "${sdk}" \
                                 "${platform}" \
                                 "${configuration}" \
                                 "${style}" \
                                 "${kitchendir}" \
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
                              "${sdk}" \
                              "${platform}" \
                              "${configuration}" \
                              "${style}" \
                              "${kitchendir}" \
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

         set -f; IFS=$'\n'
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


r_remaining_craftorder_lines()
{
   log_entry "r_remaining_craftorder_lines" "$@"

   local craftorder="$1"
   local donefile="$2"

   local remaining

   remaining="${craftorder}"
   if [ ! -z "${OPTION_SINGLE_DEPENDENCY}" ]
   then
      local escaped

      r_escaped_grep_pattern "${OPTION_SINGLE_DEPENDENCY}"
      remaining="`egrep "^[^;]*${RVAL};|\}/${RVAL};" <<< "${remaining}" `"
      log_debug "Filtered by name: ${remaining}"
      if [ -z "${remaining}" ]
      then
         fail "\"${OPTION_SINGLE_DEPENDENCY}\" is unknown in the craftorder"
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


_do_build_craftorder()
{
   log_entry "_do_build_craftorder" "$@"

   local craftorder="$1"; shift
   local kitchendir="$1"; shift
   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local style="$1"; shift

   local remaining
   local donefile

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "craftorder: ${craftorder}"
   fi

   #
   # the donefile is stored in a different place then the
   # actual buildir because that's to be determined later
   # at least for now
   #
   donefile="${kitchendir}/.${sdk}--${platform}--${configuration}.crafted"
   if [ -f "${donefile}" ]
   then
      log_fluff "Donefile \"${donefile}\" is present"
      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_trace2 "donefile: `cat "${donefile}"`"
      fi
      if ! r_remaining_craftorder_lines "${craftorder}" "${donefile}"
      then
         log_fluff "Everything in the craftorder has been crafted already"
         return
      fi
      remaining="${RVAL}"
   else
      log_fluff "Donefile \"${donefile}\" is not present, build everything"
      remaining="${craftorder}"

      mkdir_if_missing "${kitchendir}"
   fi

   #
   # remember what we built last so mulle-craft log can make a good guess
   # what the user wants to see
   #
   redirect_exekutor "${kitchendir}/.mulle-craft-last" printf "%s\n" "${sdk};${platform};${configuration}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "remaining :  ${remaining}"
   fi

   local line
   local parallel

   set -f ; IFS=$'\n'
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
                                     "${sdk}" \
                                     "${platform}" \
                                     "${configuration}" \
                                     "${style}" \
                                     "${kitchendir}" \
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
                   "${sdk}" \
                   "${platform}" \
                   "${configuration}" \
                   "${style}" \
                   "${kitchendir}" \
                   "$@"
      rval=$?

      if ! handle_build_rval "$rval" \
                             "${marks}" \
                             "${donefile}" \
                             "${line}" \
                             "${project}"
      then
         r_name_from_project "${project}"
         log_info "View logs with
${C_RESET_BOLD}   mulle-sde log $RVAL"
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
                                  "${sdk}" \
                                  "${platform}" \
                                  "${configuration}" \
                                  "${style}" \
                                  "${kitchendir}" \
                                  "$@"
      then
         return 1
      fi
   fi
   return 0
}


do_build_craftorder()
{
   log_entry "do_build_craftorder" "$@"

   local craftorderfile="$1"; shift
   local kitchendir="$1"; shift

   [ -z "${craftorderfile}" ] && internal_fail "craftorderfile is missing"
   [ -z "${kitchendir}" ]       && internal_fail "kitchendir is missing"

   [ -z "${DEPENDENCY_DIR}" ]  && fail "DEPENDENCY_DIR is undefined"
   [ -z "${CONFIGURATIONS}" ]  && internal_fail "CONFIGURATIONS is empty"
   [ -z "${SDKS}" ]            && internal_fail "SDKS is empty"
   [ -z "${PLATFORMS}" ]       && internal_fail "PLATFORMS is empty"
   [ -z "${DISPENSE_STYLE}" ]  && internal_fail "DISPENSE_STYLE is empty"

   local configurations
   local platforms
   local sdks
   local style

   configurations="${CONFIGURATIONS}"
   sdks="${SDKS}"
   platforms="${PLATFORMS}"
   style="${DISPENSE_STYLE}"

   local craftorder

   craftorder="`egrep -v '^#' "${craftorderfile}" 2> /dev/null`"
   [ $? -eq 2 ] && fail "Craftorder file \"${craftorderfile}\" is missing"

   #
   # Do this once initially, even if there are no dependencies
   # That allows tarballs to be installed. Also now the existance of the
   # dependency folders, means something
   #
   dependency_begin_update  "${style}"  || exit 1

   if [ -z "${craftorder}" ]
   then
      dependency_end_update 'complete' || exit 1
      log_verbose "The craftorder file is empty, nothing to build \
(${craftorderfile#${MULLE_USER_PWD}/})"
      return
   fi

   # patch this with environment variables ?

   local configuration
   local sdk

   set -f; IFS=':'
   for configuration in ${configurations}
   do
      assert_sane_name "${configuration}" " as configuration name"
      for platform in ${platforms}
      do
         assert_sane_name "${platform}" " as platform name"
         for sdk in ${sdks}
         do
            set +f; IFS="${DEFAULT_IFS}"

            assert_sane_name "${sdk}" " as sdk name"
            if ! _do_build_craftorder "${craftorder}" \
                                      "${kitchendir}"\
                                      "${sdk}" \
                                      "${platform}" \
                                      "${configuration}" \
                                      "${style}" \
                                      "$@"
            then
               return 1
            fi
            set -f; IFS=':'
         done
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

   local sdk="${SDKS%%,*}"
   local platform="${PLATFORMS%%,*}"
   local configuration="${CONFIGURATIONS%%,*}"
   local style="${DISPENSE_STYLE:-none}"

   sdk="${sdk:-Default}"
   platform="${platform:-Default}"
   configuration="${configuration:-Debug}"

   r_determine_craftinfo_dir "${name}" \
                             "${PWD}" \
                             "mainproject" \
                             "${OPTION_PLATFORM_CRAFTINFO}" \
                             "${OPTION_LOCAL_CRAFTINFO}" \
                             "${sdk}" \
                             "${platform}" \
                             "${configuration}" \
                             "auto"

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

   #
   # find proper build and log directory (always relax)
   #
   local kitchendir
   local stylesubdir

   kitchendir="${KITCHEN_DIR}"

   r_get_sdk_platform_configuration_style_string "${sdk}" \
                                                 "${platform}" \
                                                 "${configuration}" \
                                                 "relax"
   stylesubdir="${RVAL}"

   r_filepath_concat "${kitchendir}" "${stylesubdir}"
   kitchendir="${RVAL}"

   local logdir

   r_filepath_concat "${kitchendir}" ".log"
   logdir="${RVAL}"

   # remove old logs
   rmdir_safer "${logdir}"

   #
   # remember what we built last so mulle-craft log can make a good guess
   # what the user wants to see
   #
   mkdir_if_missing "${kitchendir}"

   # use KITCHEN_DIR not kitchendir
   redirect_exekutor "${KITCHEN_DIR}/.mulle-craft-last" printf "%s\n" "${sdk};${platform};${configuration}"

   if [ ! -z "${PROJECT_LANGUAGE}" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--language '${PROJECT_LANGUAGE}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi

   r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--build-dir '${kitchendir}'"
   OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--log-dir '${logdir}'"
   OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"

   # ugly hackage
   if [ ! -z "${configuration}" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--configuration '${configuration}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi
   if [ "${PLATFORMS}" != 'Default' ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--platform '${platform}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi
   if [ "${sdk}" != 'Default' ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--sdk '${sdk}'"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi
   if [ "${OPTION_ALLOW_SCRIPT}" = 'YES' ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "--allow-script"
      OPTIONS_MULLE_MAKE_PROJECT="${RVAL}"
   fi

   local sdk_path

   r_get_mulle_sdk_path "${sdk}" "${platform}" "${style}"
   sdk_path="${RVAL}"
   if [ ! -z "${sdk_path}" ]
   then
      r_concat "${OPTIONS_MULLE_MAKE_PROJECT}" "-DMULLE_SDK_PATH='${sdk_path}'"
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
      log_fluff "Not showing motd onrequest"
   else
      if [ -f "${kitchendir}/.motd" ]
      then
         log_fluff "Showing \"${kitchendir}/.motd\""
         exekutor cat "${kitchendir}/.motd"
      else
         log_fluff "No \"${kitchendir}/.motd\" was produced"
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
   local OPTION_PLATFORM_CRAFTINFO='YES'
   local OPTION_LOCAL_CRAFTINFO='YES'
   local OPTION_REBUILD_BUILDORDER='NO'
   local OPTION_PROTECT_DEPENDENCY='YES'
   local OPTION_ALLOW_SCRIPT="${MULLE_CRAFT_USE_SCRIPT:-DEFAULT}"
   local OPTION_SINGLE_DEPENDENCY
   local OPTION_LIST_REMAINING='NO'
   local OPTION_CLEAN_TMP='YES'
   local OPTION_PARALLEL_LINK='YES'
   local OPTION_PHASES="Headers Compile Link"
   local OPTION_PARALLEL='YES'
   local OPTION_LIBRARY_STYLE

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

         # these are dependency within craftorder, craftorder has also subproj
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
            OPTION_PLATFORM_CRAFTINFO='NO'
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL_CRAFTINFO='NO'
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
         --configuration|--configurations)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            CONFIGURATIONS="$1"
         ;;

         --library-style)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            OPTION_LIBRARY_STYLE="$1"
         ;;

         --debug)
            CONFIGURATIONS="Debug"
         ;;

         --release)
            CONFIGURATIONS="Release"
         ;;

         --test)
            CONFIGURATIONS="Test"
         ;;

         --sdk|--sdks)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            SDKS="$1"
         ;;

         --platform|--platforms)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            PLATFORMS="$1"
         ;;

         --style|--dispense-style|--dependency-style)
            [ $# -eq 1 ] && build_execute_usage "Missing argument to \"$1\""
            shift

            DISPENSE_STYLE="$1"
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

   DISPENSE_STYLE="${DISPENSE_STYLE:-none}"
   CONFIGURATIONS="${CONFIGURATIONS:-Debug}"
   SDKS="${SDKS:-Default}"
   PLATFORMS="${PLATFORMS:-Default}"

   local lastenv
   local currentenv
   local filenameenv

   [ -z "${KITCHEN_DIR}" ] && internal_fail "KITCHEN_DIR not set"
   [ -z "${MULLE_UNAME}" ] && internal_fail "MULLE_UNAME not set"

   r_absolutepath "${KITCHEN_DIR}"
   KITCHEN_DIR="${RVAL}"
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

   filenameenv="${KITCHEN_DIR}/.mulle-craft"
   currentenv="${MULLE_UNAME};${MULLE_HOSTNAME};${LOGNAME:-`id -u 2>/dev/null`}"

   lastenv="`egrep -s -v '^#' "${filenameenv}"`"
   if [ "${lastenv}" != "${currentenv}" ]
   then
      rmdir_safer "${KITCHEN_DIR}"
      mkdir_if_missing "${KITCHEN_DIR}"
      redirect_exekutor "${filenameenv}" echo "# mulle-craft environment info
${currentenv}"
   fi

   if [ -z "${MULLE_CRAFT_SEARCH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-search.sh" || exit 1
   fi
   if [ -z "${MULLE_CRAFT_SEARCHPATH_SH}" ]
   then
      . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-searchpath.sh" || exit 1
   fi

   if [ "${OPTION_USE_BUILDORDER}" = 'YES' ]
   then
      #
      # the craftorderfile is created by mulle-sde
      # mulle-craft searches no default path
      #
      if [ -z "${CRAFTORDER_FILE}" ]
      then
         fail "Failed to specify craftorder with --craftorder-file <file>"
      fi

      if [ ! -f "${CRAFTORDER_FILE}" ]
      then
         fail "Missing craftorder file \"${CRAFTORDER_FILE}\""
      fi

      [ -z "${MULLE_CRAFT_DEPENDENCY_SH}" ] && \
         . "${MULLE_CRAFT_LIBEXEC_DIR}/mulle-craft-dependency.sh"

      do_build_craftorder "${CRAFTORDER_FILE}" "${CRAFTORDER_KITCHEN_DIR}" "$@"
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


build_craftorder_main()
{
   log_entry "build_craftorder_main" "$@"

   USAGE_BUILD_STYLE="craftorder"
   USAGE_INFO="Build the craftorder only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_BUILDORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft_build_common "$@"
}


list_craftorder_main()
{
   log_entry "list_craftorder_main" "$@"

   USAGE_BUILD_STYLE="list"
   USAGE_INFO="List remaining items in craftorder to be crafted.
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

   USAGE_BUILD_STYLE="craftorder --single-dependency '${name}'"
   USAGE_INFO="Build a single dependency of the craftorder only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_BUILDORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_BUILDORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft_build_common --single-dependency "${name}" "$@"
}

