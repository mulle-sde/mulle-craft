# shellcheck shell=bash
# shellcheck disable=SC2236
# shellcheck disable=SC2166
# shellcheck disable=SC2006
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
MULLE_CRAFT_BUILD_SH='included'


craft::build::usage()
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
   --serial       : don't build in parallel
   --mulle-test   : compile for testing (defines MULLE_TEST)
   --sdk <sdk>    : specify sdk to build against (Default)
   --platform <p> : specify platform to build for (${MULLE_UNAME})
   --style <s>    : dependency style: auto, none, relax, strict, tight
   --target <t>   : target to build of project (if any)
   --             : pass remaining options to mulle-make

Environment:
   ADDICTION_DIR              : place to get addictions from (optional)
   KITCHEN_DIR                : place for intermediate craft files (required)
   CRAFTINFO_PATH             : places to find craftinfos
   DISPENSE_STYLE             : how to install into dependency (none)
   DEPENDENCY_DIR             : place to put dependencies into
   DEPENDENCY_TARBALLS        : tarballs to install into dependency, ':' sep
   MULLE_CRAFT_MAKE_FLAGS     : additional flags passed to mulle-make
   MULLE_CRAFT_CONFIGURATIONS : configurations to build, ':' separated
   MULLE_CRAFT_PLATFORMS      : platforms to build, ':' separated
   MULLE_CRAFT_SDKS           : sdks to build, ':' separated
   MULLE_CRAFT_USE_SCRIPT     : enables building with scripts

Styles:
   none    : use root only. Only useful for a single configuration/sdk/platform
   auto    : fold SDK/PLATFORM Default and CONFIGURATION Release to root
   relax   : fold SDK/PLATFORM Default but not CONFIGURATION Release
   strict  : differentiate according to SDK/PLATFORM/CONFIGURATION
   tight   : differentiate according to SDK/PLATFORM/CONFIGURATION flat

EOF
  exit 1
}


craft::build::assert_sane_name()
{
   local name="$1"; shift

   r_identifier "${name}" in

   case "${name}" in
      *--*)
         fail "\"${name}\" contains two consecutive '-' characters"
      ;;
   esac

   if [ ! -z "${name//[a-zA-Z0-9_.-]/}" ]
   then
      fail "\"${name}\" contains invalid characters$*"
   fi
}


# sets
#   _includepath
#   _frameworkspath
#   _libpath
#   _binpath
#
craft::build::__add_various_paths()
{
   log_entry "craft::build::__add_various_paths" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   _binpath="${PATH}"

   local config_sdk_platform

   craft::style::r_get_sdk_platform_configuration_string "${sdk}" \
                                                         "${platform}" \
                                                         "${configuration}" \
                                                         "${style}"
   config_sdk_platform="${RVAL}"

   log_debug "config_sdk_platform : ${config_sdk_platform}"

   if [ -d "${DEPENDENCY_DIR}/bin" ]
   then
      r_colon_concat "${DEPENDENCY_DIR}/bin" "${_binpath}"
      _binpath="${RVAL}"
   fi

   if [ ! -z "${config_sdk_platform}" ]
   then
      if [ -d "${DEPENDENCY_DIR}/${config_sdk_platform}/bin" ]
      then
         r_colon_concat "${DEPENDENCY_DIR}/${config_sdk_platform}/bin" "${_binpath}"
         _binpath="${RVAL}"
      fi
   fi

   #
   # Do addictions afterwards, so that dependency overrides addiction
   #
   if [ ! -z "${ADDICTION_DIR}" ]
   then
      local sdk_platform

      craft::style::r_get_sdk_platform_string "${sdk}" "${platform}" "${style}"
      sdk_platform="${RVAL}"

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
}


#
# local _includepath
# local _frameworkspath
# local _libpath
# local _binpath
#
craft::build::__set_various_paths()
{
   log_entry "craft::build::__set_various_paths" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   if [ ! -z "${DEPENDENCY_DIR}" ]
   then
      craft::dependency::r_include_path "${sdk}" \
                                        "${platform}" \
                                        "${configuration}" \
                                        "${style}"
      _includepath="${RVAL}"

      craft::dependency::r_lib_path "${sdk}" \
                                    "${platform}" \
                                    "${configuration}" \
                                    "${style}"
      _libpath="${RVAL}"

      case "${MULLE_UNAME}" in
         darwin)
            craft::dependency::r_frameworks_path "${sdk}" \
                                                 "${platform}" \
                                                 "${configuration}" \
                                                 "${style}"
            _frameworkspath="${RVAL}"
         ;;
      esac
   fi

   craft::build::__add_various_paths "${sdk}" \
                                     "${platform}" \
                                     "${configuration}" \
                                     "${style}"
}


craft::build::r_project_definitiondirs()
{
   log_entry "craft::build::r_project_definitiondirs" "$@"

   local project="$1"
   local name="$2"
   local allowplatform="$3"
   local sdk="$4"
   local platform="$5"
   local configuration="$6"
   local style="$7"

   #
   # if projects exist with duplicate names, add a random number at end
   # to differentiate
   #
   local definition_dirs

   # INFO_DIRS is settable as flag in mulle-craft
   definitiondirs="${INFO_DIRS}"

   if [ ! -z "${definitiondirs}" ]
   then
      RVAL="${definitiondirs}"
      return
   fi

   local extra_extension

   craft::path::r_config_extension "${name}"
   extra_extension="${RVAL}"

   local extension

   # will run once for empty extensions, which is what we want
   .foreachpath extension in "" "${extra_extension}"
   .do
      # default values provided by dependency/share/mulle-craft/definition
      craft::craftinfo::r_find_dependency_item "" \
                                               "${allowplatform}" \
                                               "${sdk}" \
                                               "${platform}" \
                                               "${configuration}" \
                                               "${style}"  \
                                               "definition${extension}"

      case $? in
         0)
            log_fluff "Adding dependency root definition \"${RVAL}\" to definitiondirs"
            r_add_line "${definitiondirs}" "${RVAL}"
            definitiondirs="${RVAL}"
         ;;

         2)
         ;;

         *)
            exit 1
         ;;
      esac
   .done

   # overrides of .mulle/share/craft/definition
   if [ "${OPTION_LOCAL_CRAFTINFO}" = 'YES' ]
   then
      .foreachpath extension in "" "${extra_extension}"
      .do
         craft::craftinfo::r_find_project_item "${name}" \
                                               "${project}" \
                                               "${allowplatform}" \
                                               "${sdk}" \
                                               "${platform}" \
                                               "definition${extension}"

         case $? in
            0)
               log_fluff "Adding project definition \"${RVAL}\" to definitiondirs"
               r_add_line "${definitiondirs}" "${RVAL}"
               definitiondirs="${RVAL}"
            ;;

            2)
            ;;

            *)
               exit 1
            ;;
         esac
      .done
   fi

   # more overrides of craftinfo in .mulle/share/craft/whatevs/definition
   .foreachpath extension in "" "${extra_extension}"
   .do
      craft::craftinfo::r_find_dependency_item "${name}" \
                                               "${allowplatform}" \
                                               "${sdk}" \
                                               "${platform}" \
                                               "${configuration}" \
                                               "${style}"  \
                                               "definition${extension}"

      case $? in
         0)
            log_fluff "Adding ${name} item \"${RVAL}\" to definitiondirs"
            r_add_line "${definitiondirs}" "${RVAL}"
            definitiondirs="${RVAL}"
         ;;

         2)
         ;;

         *)
            exit 1
         ;;
      esac
   .done

   RVAL="${definitiondirs}"
}


craft::build::build_project()
{
   log_entry "craft::build::build_project" "$@"

   local cmd="$1"
   local destination="$2"

   shift 2

   local project="$1"
   local name="$2"
   local marks="$3"
   local kitchendir="$4"
   local sdk="$5"
   local platform="$6"
   local configuration="$7"
   local style="$8"
   local phase="$9"

   shift 9

   [ -z "${cmd}" ]         && _internal_fail "cmd is empty"
   [ -z "${destination}" ] && _internal_fail "destination is empty"

   [ -z "${project}" ]     && _internal_fail "project is empty"
   [ -z "${name}" ]        && _internal_fail "name is empty"
   [ -z "${kitchendir}" ]  && _internal_fail "kitchendir is empty"
   [ -z "${phase}" ]       && _internal_fail "phase is empty"


   local definitiondirs

   craft::build::r_project_definitiondirs "${project}" \
                                          "${name}" \
                                          "${OPTION_PLATFORM_CRAFTINFO}" \
                                          "${sdk}" \
                                          "${platform}" \
                                          "${configuration}" \
                                          "${style}"
   definitiondirs="${RVAL}"

   # subdir for configuration / sdk

   local _includepath
   local _frameworkspath
   local _libpath
   local _binpath

   craft::build::__set_various_paths "${sdk}" \
                                     "${platform}" \
                                     "${configuration}" \
                                     "${style}"

   # remove old logs
   local logdir

   r_filepath_concat "${kitchendir}" ".log"
   logdir="${RVAL}"

   case "${phase}" in
      'Singlephase'|'Headers'|'Header')
         rmdir_safer "${logdir}"
      ;;
   esac

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

   case "${phase}" in
      'Singlephase')
      ;;

      'Header'|'Headers'|'Compile'|'Link')
         r_concat "${args}" "--phase ${phase}"
         args="${RVAL}"
      ;;
   esac

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
               _log_verbose "Project \"${project}\" is marked \
as \"no-static-link\" \ and \"all-load\".
This can lead to problems on darwin, but may solve problems on linux..."
            ;;
         esac
      ;;

      *',no-dynamic-link,'*)
         r_concat "${args}" "--library-style static"
         args="${RVAL}"
      ;;

      *)
         if [ ! -z "${OPTION_PREFERRED_LIBRARY_STYLE}" ]
         then
            r_concat "${args}" "--library-style ${OPTION_PREFERRED_LIBRARY_STYLE}"
            args="${RVAL}"
         fi
      ;;
   esac
#   fi

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

   if [ -z "${definitiondirs}" ]
   then
      r_concat "${args}" "--definition-dir 'NONE'" # not sure why
      args="${RVAL}"
   else
      local definitiondir

      .foreachline definitiondir in ${definitiondirs}
      .do
         r_concat "${args}" "--definition-dir '${definitiondir}'"
         args="${RVAL}"
      .done
   fi

   if [ ! -z "${configuration}" ]
   then
      r_concat "${args}" "--configuration '${configuration}'"
      args="${RVAL}"
   fi
   # TODO: hackish! fix it
   if [ "${OPTION_MULLE_TEST}" = 'YES' ]
   then
      r_concat "${args}" "--mulle-test"
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

   case "${OPTION_ALLOW_SCRIPTS}" in
      'YES')
         r_concat "${args}" "--allow-script"
         args="${RVAL}"
      ;;

      ""|'NO')
      ;;

      *)
         .foreachitem script in ${OPTION_ALLOW_SCRIPTS}
         .do
            r_concat "${args}" "--allow-build-script '${script}'"
            args="${RVAL}"
         .done
      ;;
   esac

   if [ "${OPTION_PARALLEL_MAKE}" = 'NO' ]
   then
      r_concat "${args}" "--serial"
      args="${RVAL}"
   fi


   local sdk_path

   craft::path::r_get_mulle_sdk_path "${sdk}" "${platform}"  "${configuration}" "auto"
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

   local auxargs
   local i

# MEMO: with this code: make options could be injected with environment
#       variables.
#       But we have craftinfos for this now, so a) i don't use it
#       b) its presence makes things needslessly complex
#
#   local mulle_options_env_key
#
#   include "case"
#
#   r_smart_upcase_identifier "${name}"
#   mulle_options_env_key="MULLE_CRAFT_${RVAL}_MAKE_OPTIONS"
#
#   local mulle_options_env_value
#
#   r_shell_indirect_expand "${mulle_options_env_key}"
#   mulle_options_env_value="${RVAL}"
#
#
#   if [ ! -z "${mulle_options_env_value}" ]
#   then
#      _log_verbose "Found ${C_RESET_BOLD}${mulle_options_env_key}${C_VERBOSE} \
#set to ${C_RESET_BOLD}${mulle_options_env_value}${C_VERBOSE}"
#
#      for i in ${mulle_options_env_value}
#      do
#         r_concat "${auxargs}" "'${i}'"
#         auxargs="${RVAL}"
#      done
#   else
#      log_fluff "Environment variable ${mulle_options_env_key} is not set."
#   fi

   #
   # The possiblity to add aux args via the commandline, is probably
   # occasionally useful though for one time builds
   #
   for i in "$@"
   do
      r_concat "${auxargs}" "'${i}'"
      auxargs="${RVAL}"
   done

   local flags

   case ",${marks}," in
      *,no-memo,*)
         # usally a subproject
         flags="${OPTION_NO_MEMO_MAKEFLAGS}"
      ;;
   esac

   log_setting "MULLE_TECHNICAL_FLAGS: ${MULLE_TECHNICAL_FLAGS}"
   log_setting "flags:                 ${flags}"
   log_setting "args:                  ${args}"
   log_setting "auxargs:               ${auxargs}"
   log_setting "mulle_flags_env_key:   ${mulle_flags_env_key}"
   log_setting "mulle_flags_env_value: ${mulle_flags_env_value}"

   local old

   old="${MULLE_FLAG_LOG_EXEKUTOR}"
   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      MULLE_FLAG_LOG_EXEKUTOR='YES'
   fi

   # use rexekutor because mulle-make gets the technical flags
   eval_rexekutor "${environment}" \
                     "'${MULLE_MAKE}'" \
                        "${flags}" \
                        "${MULLE_TECHNICAL_FLAGS}" \
                    "${cmd}" \
                       "${args}" \
                       "${auxargs}" \
                       "${project}" \
                       "${destination}"
   rval=$?

   MULLE_FLAG_LOG_EXEKUTOR="${old}"

   if [ ${rval} -ne 0 ]
   then
      log_fluff "Build of \"${project}\" failed ($rval)"
   fi

   if [ ! -z "${OPTION_CALLBACK}" ]
   then
      MULLE_CRAFT_PROJECT="${project}" \
      MULLE_CRAFT_DESTINATION="${destination}" \
      MULLE_CRAFT_RVAL="${rval}" \
      eval_exekutor "${OPTION_CALLBACK}" || fail "Callback failed"
   fi

   return $rval
}


craft::build::build_dependency_directly()
{
   log_entry "craft::build::build_dependency_directly" "$@"

   local cmd="$1"
   local dependency_dir="$2"

   shift 2

#   local project="$1"
#   local name="$2"
#   local marks="$3"
#   local kitchendir="$4"
#   local sdk="$5"
#   local platform="$6"
#   local configuration="$7"
   local style="$8"
#   local phase="$9"

   if [ -z "${PARALLEL_PHASE}" ]
   then
      craft::dependency::begin_update "${style}" || return 1
   fi

   local rval

   craft::build::build_project "${cmd}" \
                               "${dependency_dir}" \
                               "$@"
   rval=$?

   if [ $rval -ne 0 ]
   then
      if [ "${OPTION_LENIENT}" = 'NO' ]
      then
         return 1
      fi
      rval=1
   fi


   if [ -z "${PARALLEL_PHASE}" ]
   then
      if [ $rval != 1 ]
      then
         craft::dependency::end_update || return 1
      fi
   fi

   # signal failures downward, even if lenient
   return $rval
}


craft::build::build_dependency_with_dispense()
{
   log_entry "craft::build::build_dependency_with_dispense" "$@"

   local cmd="$1"
   local dependency_dir="$2"

   shift 2

   local project="$1"
   local name="$2"
   local marks="$3"
   local kitchendir="$4"
   local sdk="$5"
   local platform="$6"
   local configuration="$7"
   local style="$8"

   local rval
   local tmpdependency_dir

   r_filepath_concat "${kitchendir}" ".dependency"
   r_absolutepath "${RVAL}"
   tmpdependency_dir="${RVAL}"

   mkdir_if_missing "${tmpdependency_dir}"

   craft::build::build_project "${cmd}" \
                               "${tmpdependency_dir}" \
                               "$@"
   rval=$?

   log_debug "build finished with $rval"

   if [ "${cmd}" != 'install' -o $rval -ne 0 ]
   then
      if [ $rval -ne 0 ]
      then
         log_verbose "Not dispensing because of non-zero exit"
      else
         log_verbose "Not dispensing because not installing"
      fi
      rmdir_safer "${tmpdependency_dir}"
      return $rval
   fi

   local options

   options="--move"

   # ugliness for zlib
   # not very good, because include is OS specific
   # need to late eval this
   case ",${marks}," in
      *',no-rootheader,'*)
         r_concat "${options}" "--header-dir 'include/${name}'"
         options="${RVAL}"
      ;;
   esac

   case ",${marks}," in
      *',only-liftheaders,'*)
         r_concat "${options}" "--lift-headers"
         options="${RVAL}"
      ;;
   esac

   case "${PARALLEL_PHASE}" in
      "")
         craft::dependency::begin_update "${style}" || return 1
      ;;

      'Header'|'Headers')
         r_concat "${options}" --only-headers
         options="${RVAL}"
      ;;

      'Link')
         r_concat "${options}" --no-headers
         options="${RVAL}"
      ;;
   esac


   local mapper_file

   craft::craftinfo::r_find_dependency_item "${name}" \
                                            "${OPTION_PLATFORM_CRAFTINFO}" \
                                            "${sdk}" \
                                            "${platform}" \
                                            "${configuration}" \
                                            "${style}"  \
                                            "dispense-mapper.sh"

   case $? in
      0)
         log_verbose "Found dispense mapper ${C_RESET_BOLD}${mapper_file#"${MULLE_USER_PWD}/"}"
         mapper_file="${RVAL}"

         r_concat "${options}" "--mapper-file '${mapper_file}'"
         options="${RVAL}"
      ;;

      2)
      ;;

      *)
         exit 1
      ;;
   esac


   log_verbose "Dispensing product ${C_MAGENTA}${C_BOLD}${name}"
   eval_exekutor "${MULLE_DISPENSE:-mulle-dispense}" \
                  "${MULLE_TECHNICAL_FLAGS}" \
               dispense \
                  "${options}" \
                  "${tmpdependency_dir}" \
                  "${dependency_dir}"
   rval=$?

   log_debug "dispense finished with $rval"

   rmdir_safer "${tmpdependency_dir}"

   if [ -z "${PARALLEL_PHASE}" ]
   then
      if [ $rval != 1 ]
      then
         craft::dependency::end_update || return 1
      fi
   fi

   return $rval
}


#
# non-dependencies are build with their own KITCHEN_DIR
# not in the shared one.
#
craft::build::build_craftorder_node()
{
   log_entry "craft::build::build_craftorder_node" "$@"

   local cmd="$1"; shift

   local project="$1"
   local name="$2"
   local marks="$3"
#   local kitchendir="$4"
   local sdk="$5"
   local platform="$6"
   local configuration="$7"
   local style="$8"
   local phase="$9"

   # no-platform- no-build, no-build-... will be filtered out in the
   # craftorder already

   #
   # memo keeping this code here because this information could change
   # behind the back of the filtered craftorder or ?
   #
   case ",${marks}," in
      *',no-require,'*\
      |*",no-require-os-${MULLE_UNAME},"*\
      |*",no-require-platform-${platform},"*\
      |*",no-require-sdk-${sdk},"*\
      |*",no-require-configuration-${configuration},"*)
         if [ ! -d "${project}" ]
         then
            log_verbose "\"${project}\" does not exist, but it's not required"
            return 4
         fi
      ;;
   esac

   # not super sure what this does, maybe for subprojects...
   if [ "${OPTION_BUILD_DEPENDENCY}" = 'NO' ]
   then
      case ",${marks}," in
         *',no-dependency,'*)
         ;;

         *)
            log_fluff "Not building dependency \"${project}\" (complying with user wish)"
            return 4
         ;;
      esac
   fi


   #
   # Figure out where to dispense into
   #
   local dependency_dir

   craft::path::r_dependencydir "${sdk}" \
                                "${platform}" \
                                "${configuration}"  \
                                "${style}"
   dependency_dir="${RVAL}"



   #
   # Depending on marks, either install and dispense or just install
   #
   case ",${marks}," in
      *',no-inplace,'*)
         log_verbose "Build ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE} with dispense"
         craft::build::build_dependency_with_dispense "${cmd}" \
                                                      "${dependency_dir}" \
                                                      "$@"
         return $?
      ;;
   esac

   log_verbose "Build ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE}"
   craft::build::build_dependency_directly "${cmd}" \
                                           "${dependency_dir}" \
                                           "$@"
   return $?
}


craft::build::handle()
{
   log_entry "craft::build::handle" "$@"

   local cmd="$1"; shift

   local project="$1"
   local marks="$2"
   local sdk="$3"
   local platform="$4"
   local configuration="$5"
   local style="$6"
   local kitchendir="$7"
   local phase="$8"

   shift 8

   local _name
   local _evaledproject
   local _kitchendir
   local _configuration

   #
   # get remapped _configuration
   # get actual _kitchendir
   #

   craft::path::__evaluate_variables "${project}" \
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
   redirect_exekutor "${_kitchendir}/.project" printf "%s\n" "${project}" \
   || fail "Could not write into ${_kitchendir}"
   remove_file_if_present "${_kitchendir}/.status"

   local rval

   craft::build::build_craftorder_node "${cmd}" \
                                       "${_evaledproject}" \
                                       "${_name}" \
                                       "${marks}" \
                                       "${_kitchendir}" \
                                       "${sdk}" \
                                       "${platform}" \
                                       "${_configuration}" \
                                       "${style}" \
                                       "${phase}" \
                                       "$@"
   rval=$?

   log_debug "${C_RESET_BOLD}Build finished with: ${C_MAGENTA}${C_BOLD}${rval}"

   redirect_exekutor "${_kitchendir}/.status" printf "%s\n" "${rval}"  \
   || fail "Could not write into ${_kitchendir}"

   return ${rval}
}


craft::build::handle_rval()
{
   log_entry "craft::build::handle_rval" "$@"

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
               log_setting "donefile   : ${donefile}"
               log_setting "line       : ${line}"
            fi

            if [ ! -z "${donefile}" ]
            then
               redirect_append_exekutor "${donefile}" printf "%s\n" "${line}" \
               || _internal_fail "failed to append to \"${donefile}\""
            else
               log_debug "Not remembering success as we have no donefile"
            fi
         ;;
      esac
      return 0
   fi

   local evaledproject

   r_expanded_string "${project}"
   evaledproject="${RVAL}"

   if [ ${rval} -eq 1 ]
   then
      if [ "${OPTION_LENIENT}" = 'NO' ]
      then
         log_debug "Build of \"${evaledproject}\" failed, so quit"
         return 1
      fi
         _log_fluff "Ignoring build failure of \"${evaledproject}\" due to \
the enabled leniency option"
      return 0
   fi

   # 2 is OK and we warned before
   if [ ${rval} -eq 4 ]
   then
      log_debug "Ignoring harmless failure"
      return 0
   fi

   log_debug "Build of \"${evaledproject}\" returned ${rval}"
   return 1
}


craft::build::handle_step()
{
   log_entry "craft::build::handle_step" "$@"

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

   craft::build::handle "${cmd}" \
                        "${project}" \
                        "${marks}" \
                        "${sdk}" \
                        "${platform}" \
                        "${configuration}" \
                        "${style}" \
                        "${kitchendir}" \
                        "${phase}" \
                        "$@"
   rval=$?

   local phasedonefile

   if [ "${phase}" = 'Link' ]
   then
      phasedonefile="${donefile}"
   fi

   if ! craft::build::handle_rval "${rval}" \
                                  "${marks}" \
                                  "${phasedonefile}" \
                                  "${line}" \
                                  "${project}"
   then
      redirect_append_exekutor "${statusfile}" printf "%s\n" "${project};${phase};${rval}"
   fi
}


craft::build::handle_parallel()
{
   log_entry "craft::build::handle_parallel" "$@"

   local parallel="$1"
   local donefile="$2"

   shift 2

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"
   local kitchendir="$5"

   shift 5

   [ -z "${parallel}" ]      && _internal_fail "v is empty"
   [ -z "${configuration}" ] && _internal_fail "configuration is empty"
   [ -z "${platform}" ]      && _internal_fail "platform is empty"
   [ -z "${sdk}" ]           && _internal_fail "sdk is empty"
   [ -z "${style}" ]         && _internal_fail "style is empty"
   [ -z "${kitchendir}" ]    && _internal_fail "kitchendir is empty"

   local statusfile

   _r_make_tmp_in_dir "${KITCHEN_DIR}" ".build-status" "f" || exit 1
   statusfile="${RVAL}"

   local parallel_link='NO'

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
      if rexekutor grep -E -v '[;,]no-singlephase-link[;,]|[;,]no-singlephase-link$' <<< "${parallel}"
      then
         log_fluff "Not all parallel builds are marked as no-singlephase-link, use sequential link"
         parallel_link='NO'
      else
         log_fluff "All parallel builds can also be parallel linked"
      fi
   else
      log_fluff "Parallel linking is not enabled"
   fi

   log_setting "parallel : ${parallel}"

   local project
   local marks
   local phase 
   local failures
   local line
   local PARALLEL_PHASE
   local cmd

   shell_disable_glob
   for phase in ${OPTION_PHASES}
   do
      log_verbose "Starting phase ${phase}"

      PARALLEL_PHASE="${phase}"

      case "${phase}" in
         'Header'|'Headers')
            craft::dependency::begin_update "${style}" || return 1
            cmd='install'
         ;;

         Compile)
            cmd='build'
         ;;

         Link)
            cmd='install'
         ;;

         *)
            fail "Unknown phase \"${phase}\", need one of: Header,Compile,Link"
         ;;
      esac

      .foreachline line in ${parallel}
      .do
         IFS=";" read -r project marks <<< "${line}"

         # need a project and not empty spaces
         [ -z "${project## }" ] && _internal_fail "project is empty"

         #
         # TODO: we are somewhat overoptimistic, that we don't build
         #       1000 projects in parallel here and run into system
         #       limitations...
         #
         if [ "${phase}" != 'Link' -o "${parallel_link}" = 'YES' ] && [ "${OPTION_PARALLEL_PHASE}" = 'YES' ]
         then
            (
               craft::build::handle_step "${cmd}" \
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
            craft::build::handle_step "${cmd}" \
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
      .done

      shell_enable_glob; IFS="${DEFAULT_IFS}"

      # collect phases
      log_fluff "Waiting for phase ${phase} to complete"

      wait

      log_verbose "Phase ${phase} complete"

      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_setting "Return values: `cat "${statusfile}"`"
      fi

      failures="`cat "${statusfile}"`"

      if [ ! -z "${failures}" ]
      then
         log_fluff "Errors detected in \"${statusfile}\": ${failures}"


         .foreachline line in ${failures}
         .do
            project="${line%;*}"      # project;phase (remove ;rval)
            phase="${project#*;}"
            project="${project%;*}"
            log_error "Parallel build of \"${project}\" failed in phase \"${phase}\""
         .done

         remove_file_if_present "${statusfile}"

         shell_enable_glob
         return 1
      fi

      case "${phase}" in
         Link)
            craft::dependency::end_update || return 1
         ;;
      esac
   done
   shell_enable_glob

   remove_file_if_present "${statusfile}"

   return 0
}


craft::build::r_remaining_craftorder_lines()
{
   log_entry "craft::build::r_remaining_craftorder_lines" "$@"

   local craftorder="$1"
   local donefile="$2"
   local shared_donefile="$3"

   local remaining

   #
   # weed out those that are in the shared donefile, which we don't have to
   # build anyway
   #
   remaining="${craftorder}"
   if [ ! -z "${shared_donefile}" ] && [ -f "${shared_donefile}" ]
   then
      local remaining_after_shared

      remaining_after_shared="`rexekutor grep -F -x -v -f "${shared_donefile}" <<< "${remaining}"`"
      if [ "${remaining_after_shared}" != "${remaining}" ]
      then
         if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
         then
            _log_setting "Remaining
----
${remaining}
----
reduced to
----
${remaining_after_shared}
----
"
         fi
         remaining="${remaining_after_shared}"
      else
         log_verbose "Craftorder unchanged after applying the shared donefile"
      fi
   fi

   if [ ! -z "${OPTION_SINGLE_DEPENDENCY}" ]
   then
      local escaped
      local remaining_after_single

      r_escaped_grep_pattern "${OPTION_SINGLE_DEPENDENCY}"
      remaining_after_single="`grep -E "^[^;]*${RVAL};|\}/${RVAL};" <<< "${remaining}" `"
      log_debug "Filtered by name: ${remaining_after_single}"
      if [ -z "${remaining_after_single}" ]
      then
         fail "\"${OPTION_SINGLE_DEPENDENCY}\" is unknown in the craftorder"
      fi

      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         _log_setting "Remaining
----
${remaining}
----
reduced to
----
${remaining_after_single}
----
"
      fi      
      RVAL="${remaining_after_single}"
      return 0
   fi

   if [ ! -z "${donefile}" ] && [ -f "${donefile}" ]
   then
      if [ "${OPTION_REBUILD_BUILDORDER}" = 'YES' ]
      then
         remove_file_if_present "${donefile}"
      else
         local remaining_after_donefile

         remaining_after_donefile="`rexekutor grep -F -x -v -f "${donefile}" <<< "${remaining}"`"
         if [ "${remaining_after_donefile}" != "${remaining}" ]
         then
            if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
            then
               _log_setting "Remaining
----
${remaining}
----
reduced to
----
${remaining_after_donefile}
----
"
            else
               log_fluff "Craftorder unchanged after applying the donefile"
            fi
         fi

         RVAL="${remaining_after_donefile}"
         [ ! -z "${RVAL}" ] 
         return $?
      fi
   fi

   RVAL="${remaining}"
   return 0
}



craft::build::_do_craftorder()
{
   log_entry "craft::build::_do_craftorder" "$@"

   local craftorder="$1"
   local kitchendir="$2"
   local version="$3"
   local sdk="$4"
   local platform="$5"
   local configuration="$6"
   local style="$7"

   shift 7

   log_setting "craftorder      : ${craftorder}"

   local remaining

   remaining="${craftorder}"

   local _donefile
   local _shared_donefile  # filled by craft::style::__have_donefiles sideeffect

   local rval

   rval=48

   if [ "${OPTION_DONEFILES}" = 'YES' ]
   then
      include "craft::donefile"

      craft::donefile::__have_donefiles "${sdk}" "${platform}" "${configuration}"
      rval=$?

      log_setting "donefile        : ${_donefile}"
      log_setting "shared_donefile : ${_shared_donefile}"

      if [ $rval -eq 0 ]
      then
         if ! craft::build::r_remaining_craftorder_lines "${craftorder}" \
                                                         "${_donefile}" \
                                                         "${_shared_donefile}"
         then
            log_fluff "Everything in the craftorder has been crafted already"
            return
         fi
         remaining="${RVAL}"
      else
         _log_fluff "No donefiles \"${_donefile#"${MULLE_USER_PWD}/"}\" or \
\"${_shared_donefile#"${MULLE_USER_PWD}/"}\" are present, so build everything"
      fi
   else
      log_fluff "No donefiles allowed, so build everything"
   fi

   local donefile="${_donefile}"

   #
   # remember what we built last so mulle-craft log can make a good guess
   # what the user wants to see
   #

   mkdir_if_missing "${kitchendir}"

   redirect_exekutor "${kitchendir}/.mulle-craft-last" \
      printf "%s\n" "${sdk};${platform};${configuration}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_setting "remaining :  ${remaining}"
   fi

   local line
   local parallel
   local project
   local marks
   local is_parallel_enabled

   is_parallel_enabled='NO'
   if [ "${OPTION_PARALLEL}" = 'YES' -a  \
        "${OPTION_LIST_REMAINING}" = 'NO' -a \
        "${MULLE_CRAFT_FORCE_SINGLEPHASE}" != 'YES' -a \
        -z "${OPTION_SINGLE_DEPENDENCY}" ]
   then
      is_parallel_enabled='YES'
   fi

   log_fluff "is_parallel_enabled : ${is_parallel_enabled}"

   .foreachline line in ${remaining}
   .do
      project="${line%%;*}"
      marks="${line#*;}"

      [ -z "${project## }" ] && _internal_fail "empty project fail"

      if [ "${is_parallel_enabled}" = 'YES' ]
      then
         case ",${marks}," in
            *,no-singlephase,*)
               case ",${marks}," in
                  *,only-framework,*)
                     _log_warning "${project} is marked as no-singlephase and \
only-framework.
${C_INFO}Frameworks can not be built with multi-phase currently."
                  ;;
               esac

               r_add_line "${parallel}" "${line}"
               parallel="${RVAL}"
               log_fluff "Collected \"${line}\" for parallel build"
               .continue
            ;;
         esac
      fi

      if [ ! -z "${parallel}" ]
      then
         if ! craft::build::handle_parallel "${parallel}" \
                                            "${_donefile}" \
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

      craft::build::handle "install" \
                           "${project}" \
                           "${marks}" \
                           "${sdk}" \
                           "${platform}" \
                           "${configuration}" \
                           "${style}" \
                           "${kitchendir}" \
                           "Singlephase" \
                           "$@"
      rval=$?

      if ! craft::build::handle_rval "$rval" \
                                     "${marks}" \
                                     "${donefile}" \
                                     "${line}" \
                                     "${project}"
      then
         craft::path::r_name_from_project "${project}"

         _log_info "View logs with
${C_RESET_BOLD}   mulle-sde log $RVAL"
         return 1
      fi

      if [ ! -z "${OPTION_SINGLE_DEPENDENCY}" ]
      then
         return $rval
      fi
   .done

   # left over parallel
   if [ ! -z "${parallel}" ]
   then
      if ! craft::build::handle_parallel "${parallel}" \
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


craft::build::do_craftorder()
{
   log_entry "craft::build::do_craftorder" "$@"

   local craftorderfile="$1"; shift
   local kitchendir="$1"; shift
   local version="$1"; shift

   [ -z "${craftorderfile}" ]  && _internal_fail "craftorderfile is missing"
   [ -z "${kitchendir}" ]      && _internal_fail "kitchendir is missing"

   [ -z "${DEPENDENCY_DIR}" ]  && fail "DEPENDENCY_DIR is undefined"
   [ -z "${DISPENSE_STYLE}" ]  && _internal_fail "DISPENSE_STYLE is empty"

   #
   # "NONE" creates no dependency folder
   #
   if [ "${craftorderfile}" = "NONE" ]
   then
      craft::dependency::end_update 'complete' || exit 1
      log_verbose "The craftorder file is NONE, nothing to build"
      return
   fi

   local craftorder
   local style

   style="${DISPENSE_STYLE}"
   craftorder="`grep -E -v '^#' "${craftorderfile}" 2> /dev/null`"
   [ $? -gt 1 ] && fail "Craftorder file \"${craftorderfile}\" is missing"

   #
   # Do this once initially, even if there are no dependencies
   # That allows tarballs to be installed. Also now the existence of the
   # dependency folders, means something
   #
   craft::dependency::begin_update  "${style}"  || exit 1

   if [ -z "${craftorder}" ]
   then
      craft::dependency::end_update 'complete' || exit 1
      _log_verbose "The craftorder file is empty, nothing to build \
(${craftorderfile#"${MULLE_USER_PWD}/"})"
      return
   fi

   # IDEE: Was wir gerne hätten wäre, daß mulle-sde craft gleich auch noch
   #       auf macOS für mehrere ARCHs zusammenbaut. `cmake` kann das von sich
   #       aus, von daher bräuchten wir keine "ARCHS" in mulle-craft.
   #       mulle-make hingegen könnte das für "autoconf/configure" Projekte
   #       machen und nach dem man für beides gebaut hat (in temporären
   #       build verzeichnissen) das ganze dann zusammenführen. Was dann quasi
   #       lipo macht. Macht das dann wieder mulle-dispense ?
   #       Auf linux oder anderen Systemen müsste man die libraries kopieren
   #       und irgendwie mit nem suffix versehen oder so.
   #       Einziges Problem. Ev. hat man zwei verschiedene SDKs, eins für
   #       ARM und eins für x86_64 und was macht man dann ?
   #

   [ -z "${MULLE_CRAFT_CONFIGURATIONS}" ]  && _internal_fail "MULLE_CRAFT_CONFIGURATIONS is empty"
   [ -z "${MULLE_CRAFT_SDKS}" ]            && _internal_fail "MULLE_CRAFT_SDKS is empty"
   [ -z "${MULLE_CRAFT_PLATFORMS}" ]       && _internal_fail "MULLE_CRAFT_PLATFORMS is empty"

   local configuration
   local platform
   local sdk
   local filtered
   local match_version

   .foreachpath platform in ${MULLE_CRAFT_PLATFORMS}
   .do
      craft::build::assert_sane_name "${platform}" " as platform name (use ':' as separator)"
      .foreachpath sdk in ${MULLE_CRAFT_SDKS}
      .do
         craft::build::assert_sane_name "${sdk}" " as sdk name (use ':' as separator)"

         craft::qualifier::r_determine_platform_sdk_version "${platform}" "${sdk}" "${version}"
         match_version="${RVAL}"

         .foreachpath configuration in ${MULLE_CRAFT_CONFIGURATIONS}
         .do
            craft::build::assert_sane_name "${configuration}" " as configuration name (use ':' as separator)"

            craft::qualifier::r_filtered_craftorder "${craftorder}" \
                                                    "${sdk}" \
                                                    "${platform}" \
                                                    "${configuration}" \
                                                    "${match_version}"
            filtered="${RVAL}"

            if ! craft::build::_do_craftorder "${filtered}" \
                                              "${kitchendir}" \
                                              "${match_version}" \
                                              "${sdk}" \
                                              "${platform}" \
                                              "${configuration}" \
                                              "${style}" \
                                              "$@"
            then
               return 1
            fi
         .done
      .done
   .done

   craft::dependency::end_update 'complete' || exit 1
}


craft::build::r_mainproject_definition_dirs()
{
   log_entry "craft::build::r_mainproject_definition_dirs" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"
   local name="$5"
   local projectdir="$6"

   local extra_extension

   craft::path::r_config_extension "${name}"
   extra_extension="${RVAL}"

   # should use INFO_DIRS here ?
   local definitiondirs

   # default values provided by dependency/share/mulle-craft/definition
   # will run once for empty extensions, which is what we want
   .foreachpath extension in "" ${extra_extension}
   .do
      craft::craftinfo::r_find_dependency_item "" \
                                               "${OPTION_PLATFORM_CRAFTINFO}" \
                                               "${sdk}" \
                                               "${platform}" \
                                               "${configuration}" \
                                               "${style}"  \
                                               "definition${extension}"

      case $? in
         0)
            log_debug "Adding \"${RVAL}\" to definitiondirs"
            r_add_line "${definitiondirs}" "${RVAL}"
            definitiondirs="${RVAL}"
         ;;

         2)
         ;;

         *)
            exit 1
         ;;
      esac
   .done

   #
   # override with local info
   #
   .foreachpath extension in "" ${extra_extension}
   .do
      craft::craftinfo::r_find_project_item "${name}" \
                                            "${projectdir}" \
                                            "${OPTION_PLATFORM_CRAFTINFO}" \
                                            "${sdk}" \
                                            "${platform}" \
                                            "definition${extension}"

      case $? in
         0)
            log_debug "Adding \"${RVAL}\" to definitiondirs"
            r_add_line "${definitiondirs}" "${RVAL}"
            definitiondirs="${RVAL}"
         ;;

         2)
         ;;

         *)
            exit 1
         ;;
      esac
   .done

   RVAL="${definitiondirs}"
}


craft::build::build_mainproject()
{
   log_entry "craft::build::build_mainproject" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"
   local name="$5"
   local projectdir="$6"

   shift 6

   local definitiondirs

   definitiondirs="${INFO_DIRS}"
   if [ -z "${definitiondirs}" ]
   then
      craft::build::r_mainproject_definition_dirs "${sdk}" \
                                                  "${platform}" \
                                                  "${configuration}" \
                                                  "${style}" \
                                                  "${name}" \
                                                  "${projectdir}"
      definitiondirs="${RVAL}"
   fi

   local options

   options="${OPTIONS_MULLE_MAKE_PROJECT}"

   # always set --definition-dir
   if [ -z "${definitiondirs}" ]
   then
      r_concat "${options}" "--definition-dir 'NONE'" # not sure why
      options="${RVAL}"
   else
      local definitiondir

      .foreachline definitiondir in ${definitiondirs}
      .do
         r_concat "${options}" "--definition-dir '${definitiondir}'"
         options="${RVAL}"
      .done
   fi

   # we need mostly binpath here
   local _includepath
   local _frameworkspath
   local _libpath
   local _binpath

   craft::build::__set_various_paths "${sdk}" \
                                     "${platform}" \
                                     "${configuration}" \
                                     "${style}"

   #
   # find proper build and log directory (always relax)
   #
   local kitchendir

   craft::path::r_mainproject_kitchendir "${sdk}" \
                                         "${platform}" \
                                         "${configuration}" \
                                         "${style}" \
                                         "${KITCHEN_DIR}"
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

   remove_file_if_present "${kitchendir}/.status"

   redirect_exekutor "${kitchendir}/.project" printf "%s\n" "${name}" \
   || fail "Could not write into ${kitchendir}"

   # use KITCHEN_DIR not kitchendir
   redirect_exekutor "${KITCHEN_DIR}/.mulle-craft-last" \
      printf "# remember sdk;platform;configuration used for build
%s\n" "${sdk};${platform};${configuration}"

   if [ ! -z "${PROJECT_LANGUAGE}" ]
   then
      r_concat "${options}" "--language '${PROJECT_LANGUAGE}'"
      options="${RVAL}"
   fi
   if [ ! -z "${PROJECT_DIALECT}" ]
   then
      r_concat "${options}" "--dialect '${PROJECT_DIALECT}'"
      options="${RVAL}"
   fi

   r_concat "${options}" "--build-dir '${kitchendir}'"
   options="${RVAL}"

   r_concat "${options}" "--log-dir '${logdir}'"
   options="${RVAL}"

   if [ "${_binpath}" != "${PATH}" ]
   then
      r_concat "${options}" "--path '${_binpath}'"
      options="${RVAL}"
   fi

   # ugly hackage
   if [ ! -z "${OPTION_TARGETS}" ]
   then
      r_concat "${options}" "--targets '${OPTION_TARGETS}'"
      options="${RVAL}"
   fi
   if [ ! -z "${configuration}" ]
   then
      r_concat "${options}" "--configuration '${configuration}'"
      options="${RVAL}"
   fi
   if [ "${OPTION_MULLE_TEST}" = 'YES' ]
   then
      r_concat "${options}" "--mulle-test"
      options="${RVAL}"
   fi
   if [ "${platform}" != "${MULLE_UNAME}" ]
   then
      r_concat "${options}" "--platform '${platform}'"
      options="${RVAL}"
   fi
   if [ "${sdk}" != 'Default' ]
   then
      r_concat "${options}" "--sdk '${sdk}'"
      options="${RVAL}"
   fi

   case "${OPTION_ALLOW_SCRIPTS}" in
      'YES')
         r_concat "${options}" "--allow-script"
         options="${RVAL}"
      ;;

      ""|'NO')
      ;;

      *)
         .foreachitem script in ${OPTION_ALLOW_SCRIPTS}
         .do
            r_concat "${options}" "--allow-build-script '${script}'"
            options="${RVAL}"
         .done
      ;;
   esac

   if [ "${OPTION_PARALLEL_MAKE}" = 'NO' ]
   then
      r_concat "${options}" "--serial"
      options="${RVAL}"
   fi

   local sdk_path


   craft::path::r_get_mulle_sdk_path "${sdk}" "${platform}" "${configuration}" "${style}"
   sdk_path="${RVAL}"

   if [ ! -z "${sdk_path}" ]
   then
      r_concat "${options}" "-DMULLE_SDK_PATH='${sdk_path}'"
      options="${RVAL}"
   fi

   # MEMO: do this properly with escaping of '
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

   local old

   old="${MULLE_FLAG_LOG_EXEKUTOR}"
   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      MULLE_FLAG_LOG_EXEKUTOR='YES'
   fi

   local rval

   # never install the project, use mulle-make for that
   eval_rexekutor "'${MULLE_MAKE}'" \
                        "${MULLE_TECHNICAL_FLAGS}" \
                     "build" \
                        "${options}" \
                        "${auxargs}"
   rval=$?

   MULLE_FLAG_LOG_EXEKUTOR="${old}"

   redirect_exekutor "${kitchendir}/.status" printf "%s\n" "${rval}" \
   || fail "Could not write into ${kitchendir}"

   if [ $rval -ne 0 ]
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


craft::build::do_mainproject()
{
   log_entry "craft::build::do_mainproject" "$@"

   local name

   name="${PROJECT_NAME}"
   if [ -z "${PROJECT_NAME}" ]
   then
      r_basename "${PWD}"
      name="${RVAL}"
   fi

   [ -z "${MULLE_CRAFT_CONFIGURATIONS}" ]  && _internal_fail "MULLE_CRAFT_CONFIGURATIONS is empty"
   [ -z "${MULLE_CRAFT_SDKS}" ]            && _internal_fail "MULLE_CRAFT_SDKS is empty"
   [ -z "${MULLE_CRAFT_PLATFORMS}" ]       && _internal_fail "MULLE_CRAFT_PLATFORMS is empty"

   local configuration
   local platform
   local sdk

   local match_version
   local blurb

   include "craft::qualifier"

   .foreachpath platform in ${MULLE_CRAFT_PLATFORMS}
   .do
      craft::build::assert_sane_name "${platform}" " as platform name (use ':' as separator)"

      .foreachpath sdk in ${MULLE_CRAFT_SDKS}
      .do
         craft::build::assert_sane_name "${sdk}" " as sdk name (use ':' as separator)"

         craft::qualifier::r_determine_platform_sdk_version "${platform}" "${sdk}" "${version}"
         match_version="${RVAL}"

         .foreachpath configuration in ${MULLE_CRAFT_CONFIGURATIONS}
         .do
            craft::build::assert_sane_name "${configuration}" " as configuration name (use ':' as separator)"

            if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
            then
               blurb="Craft main project ${C_MAGENTA}${C_BOLD}${name}${C_VERBOSE} \
as a ${C_MAGENTA}${C_BOLD}${configuration}${C_VERBOSE} build"
               if [ "${platform}" != "Default" ]
               then
                  blurb="${blurb} for ${C_MAGENTA}${C_BOLD}${platform}${C_VERBOSE}"
               fi
               if [ "${sdk}" != "Default" ]
               then
                  blurb="${blurb} with ${C_MAGENTA}${C_BOLD}${sdk}${C_VERBOSE}"
               fi
               log_verbose "${blurb}"
            fi

            if ! craft::build::build_mainproject "${sdk}" \
                                                 "${platform}" \
                                                 "${configuration}" \
                                                 "${DISPENSE_STYLE:-auto}" \
                                                 "${name}" \
                                                 "" \
                                                 "$@"
            then
               return 1
            fi
         .done
      .done
   .done
}


#
# mulle-craft isn't ruled so much by command line arguments
# but uses mostly ENVIRONMENT variables
# These are usually provided with mulle-sde.
#
craft::build::common()
{
   log_entry "craft::build::common" "$@"

   local OPTION_ALLOW_SCRIPTS="${MULLE_CRAFT_USE_SCRIPTS:-${MULLE_CRAFT_USE_SCRIPT:-}}"
   local OPTION_BUILD_DEPENDENCY="DEFAULT"
   local OPTION_CLEAN_TMP='YES'
   local OPTION_DONEFILES='YES'
   local OPTION_KEEP_DEPENDENCY_STATE='YES'
   local OPTION_LENIENT='NO'
   local OPTION_LIST_REMAINING='NO'
   local OPTION_LOCAL_CRAFTINFO="${MULLE_CRAFT_LOCAL_CRAFTINFO:-YES}"
   local OPTION_MULLE_TEST='NO'
   local OPTION_PARALLEL='YES'
   local OPTION_PARALLEL_LINK='YES'
   local OPTION_PARALLEL_MAKE='YES'
   local OPTION_PARALLEL_PHASE='YES' # NO sometimes usefule for debugging
   local OPTION_PHASES="Headers Compile Link"
   local OPTION_PLATFORM_CRAFTINFO="${MULLE_CRAFT_PLATFORM_CRAFTINFO:-YES}"
   local OPTION_PREFERRED_LIBRARY_STYLE
   local OPTION_PROTECT_DEPENDENCY='YES'
   local OPTION_REBUILD_BUILDORDER='NO'
   local OPTION_SINGLE_DEPENDENCY
   local OPTION_VERSION=DEFAULT
   local OPTIONS_MULLE_MAKE_PROJECT=
   local OPTION_TARGETS=
   local OPTION_CALLBACK

   # header install phase currently not installing for some reason
#  case "${MULLE_UNAME}" in
#     windows|mingw)
#        OPTION_PARALLEL='NO'
#     ;;
#  esac

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft::build::usage
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
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            OPTION_NO_MEMO_MAKEFLAGS="$1"  # could be global env
         ;;

         # these are dependency within craftorder, craftorder has also subproj
         --allow-all-scripts|--allow-script)
            OPTION_ALLOW_SCRIPTS='YES'
         ;;

         --allow-build-script)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            if [ "${OPTION_ALLOW_SCRIPTS}" != 'YES' ]
            then
               if [ "${OPTION_ALLOW_SCRIPTS}" = 'NO' ]
               then
                  OPTION_ALLOW_SCRIPTS="${RVAL}"
               else
                  r_comma_concat "${OPTION_ALLOW_SCRIPTS}" "$1"
                  OPTION_ALLOW_SCRIPTS="${RVAL}"
               fi
            fi
         ;;

         --no-allow-script)
            OPTION_ALLOW_SCRIPTS='NO'
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

         --no-keep-dependency-state)
            OPTION_KEEP_DEPENDENCY_STATE='NO'
         ;;

         --callback)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            OPTION_CALLBACK="$1"
         ;;

         --phases)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            OPTION_PHASES="$1"
            OPTION_PHASES="${OPTION_PHASES//[;:,]/ }"
         ;;

         --parallel)
            OPTION_PARALLEL='YES'
            OPTION_PARALLEL_MAKE='YES'
         ;;

         --no-parallel|--serial)
            OPTION_PARALLEL='NO'
            OPTION_PARALLEL_MAKE='NO'
         ;;

         --parallel-make)
            OPTION_PARALLEL_MAKE='YES'
         ;;

         --no-parallel-make|--serial-make)
            OPTION_PARALLEL_MAKE='NO'
         ;;

         --parallel-link)
            OPTION_PARALLEL_LINK='YES'
         ;;

         --no-parallel-link|--serial-link)
            OPTION_PARALLEL_LINK='NO'
         ;;

         --no-parallel-phase|--serial-phase)
            OPTION_PARALLEL_PHASE='NO'
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

         --no-donefiles)
            OPTION_DONEFILES='NO'
         ;;

         --no-local|--no-local-craftinfo)
            OPTION_LOCAL_CRAFTINFO='NO'
         ;;

         --list-remaining)
            OPTION_LIST_REMAINING='YES'
         ;;

         --single-dependency)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

				OPTION_SINGLE_DEPENDENCY="$1"
			;;

         #
         # config / sdk
         #
         --configuration|--configurations)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            MULLE_CRAFT_CONFIGURATIONS="$1"
         ;;

         --preferred-library-style|--library-style)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            OPTION_PREFERRED_LIBRARY_STYLE="$1"
         ;;

         --debug)
            MULLE_CRAFT_CONFIGURATIONS="Debug"
         ;;

         --release)
            MULLE_CRAFT_CONFIGURATIONS="Release"
         ;;

         --mulle-test)
            OPTION_MULLE_TEST='YES'
         ;;

         --sdk|--sdks)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            MULLE_CRAFT_SDKS="$1"
         ;;

         --platform|--platforms)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            MULLE_CRAFT_PLATFORMS="$1"
         ;;

         --style|--dispense-style|--dependency-style)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            DISPENSE_STYLE="$1"
         ;;

         --target|--targets)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            OPTION_TARGETS="$1"
         ;;


         --version)
            [ $# -eq 1 ] && craft::build::usage "Missing argument to \"$1\""
            shift

            OPTION_VERSION="$1"
         ;;


         \'-*)
            fail "Single quoted option is an escaping fail"
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

   [ -z "${KITCHEN_DIR}" ] && _internal_fail "KITCHEN_DIR not set"
   [ -z "${MULLE_UNAME}" ] && _internal_fail "MULLE_UNAME not set"

   DISPENSE_STYLE="${DISPENSE_STYLE:-auto}"
   MULLE_CRAFT_CONFIGURATIONS="${MULLE_CRAFT_CONFIGURATIONS:-Debug}"
   MULLE_CRAFT_SDKS="${MULLE_CRAFT_SDKS:-Default}"
   MULLE_CRAFT_PLATFORMS="${MULLE_CRAFT_PLATFORMS:-Default}"

   local currentenv
   local filenameenv

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

   filenameenv="${KITCHEN_DIR}/.mulle-craft"
   currentenv="${MULLE_UNAME};${MULLE_HOSTNAME};${MULLE_USERNAME}"

   local lastenv

   if [ -f "${filenameenv}" ]
   then
      lastenv="`grep -E -v '^#' "${filenameenv}"`" # solaris cant do -s
   fi

   if [ "${lastenv}" != "${currentenv}" ]
   then
      rmdir_safer "${KITCHEN_DIR}"
      mkdir_if_missing "${KITCHEN_DIR}"
      redirect_exekutor "${filenameenv}" echo "# mulle-craft environment info
# For verification that ${KITCHEN_DIR} contents are valid, if it gets copied to another machine
${currentenv}"
   fi

   log_setting "DISPENSE_STYLE             : \"${DISPENSE_STYLE}\""
   log_setting "MULLE_CRAFT_CONFIGURATIONS : \"${MULLE_CRAFT_CONFIGURATIONS}\""
   log_setting "MULLE_CRAFT_SDKS           : \"${MULLE_CRAFT_SDKS}\""
   log_setting "MULLE_CRAFT_PLATFORMS      : \"${MULLE_CRAFT_PLATFORMS}\""
   log_setting "CRAFTORDER_FILE            : \"${CRAFTORDER_FILE}\""

   include "craft::style"
   include "craft::path"
   include "craft::craftinfo"
   include "craft::searchpath"
   include "craft::qualifier"
   include "craft::dependency"

   if [ "${OPTION_USE_CRAFTORDER}" = 'YES' ]
   then
      #
      # the craftorderfile is created by mulle-sde
      # mulle-craft searches no default path
      #
      if [ -z "${CRAFTORDER_FILE}" ]
      then
         fail "You must specify the craftorder with --craftorder-file <file>"
      fi

      if [ "${CRAFTORDER_FILE}" != "NONE" -a ! -f "${CRAFTORDER_FILE}" ]
      then
         fail "Missing craftorder file \"${CRAFTORDER_FILE}\""
      fi

      craft::build::do_craftorder "${CRAFTORDER_FILE}" \
                                  "${CRAFTORDER_KITCHEN_DIR}" \
                                  "${OPTION_VERSION}" \
                                  "$@"
      return $?
   fi

   #
   # Build the project
   #
   [ "${OPTION_USE_PROJECT}" = 'YES' ] || _internal_fail "hein ?"

   # don't build if only headers are built for example
   case "${OPTION_PHASES}" in
      *Link*)
         craft::build::do_mainproject "$@"
      ;;
   esac
}


craft::build::project_main()
{
   log_entry "craft::build::project_main" "$@"

   USAGE_BUILD_STYLE="project"
   USAGE_INFO="Build the project only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_CRAFTORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='YES'
   OPTION_USE_CRAFTORDER='NO'
   OPTION_MUST_HAVE_BUILDORDER='NO'

   craft::build::common "$@"
}


craft::build::craftorder_main()
{
   log_entry "craft::build::craftorder_main" "$@"

   USAGE_BUILD_STYLE="craftorder"
   USAGE_INFO="Build projects according to a given craftorder file.
   Specify the craftorder with the command *flag* --craftorder-file <path>.
   The craftorder file specifies the projects to craft on each line and in
   order of their dependencies amongst each other.  A line is made up of the
   form <path>;<marks>. Where marks are comma separated identifiers, typically
   starting with 'no-'. For example a project, that partakes in multiphase
   craft, has a 'no-singlephase' mark. Projects that are header only have a
   'no-link' mark. There are lots of other marks. See the mulle-sde Wiki for
   more information.

Example:
   cat <<EOF > file.txt
   stash/tiny;no-link,no-singlephase
   stash/foo;no-singlephase
   stash/bar;no-singlephase
   EOF
   ${MULLE_USAGE_NAME} --craftorder-file file.txt craftorder"

   local OPTION_USE_PROJECT
   local OPTION_USE_CRAFTORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_CRAFTORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft::build::common "$@"
}


craft::build::list_craftorder_main()
{
   log_entry "craft::build::list_craftorder_main" "$@"

   USAGE_BUILD_STYLE="list"
   USAGE_INFO="List remaining items in craftorder to be crafted.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_CRAFTORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_CRAFTORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft::build::common --list-remaining "$@"
}


craft::build::single_dependency_main()
{
   log_entry "craft::build::single_dependency_main" "$@"

   local name="$1"; shift

   USAGE_BUILD_STYLE="craftorder --single-dependency '${name}'"
   USAGE_INFO="Build a single dependency of the craftorder only.
"
   local OPTION_USE_PROJECT
   local OPTION_USE_CRAFTORDER
   local OPTION_MUST_HAVE_BUILDORDER

   OPTION_USE_PROJECT='NO'
   OPTION_USE_CRAFTORDER='YES'
   OPTION_MUST_HAVE_BUILDORDER='YES'

   craft::build::common --single-dependency "${name}" "$@"
}

