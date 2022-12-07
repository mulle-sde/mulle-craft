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
MULLE_CRAFT_PATH_SH="included"

#
# local _configuration
# local _evaledproject
# local _name
#
craft::path::r_mapped_configuration()
{
   log_entry "craft::path::r_mapped_configuration" "$@"

   local name="$1"
   local configuration="$2"

   include "case"

   local base_identifier

   r_smart_upcase_identifier "${name}"
   base_identifier="${RVAL}"

   #
   # Map some configurations (e.g. Debug -> Release for mulle-objc-runtime)
   # You can also map to empty, to skip a configuration
   #
   local value
   local identifier

   identifier="MULLE_CRAFT_${base_identifier}_MAP_CONFIGURATIONS"
   r_shell_indirect_expand "${identifier}"
   value="${RVAL}"

   RVAL="${configuration}"
   if [ -z "${value}" ]
   then
      return
   fi

   local mapped
   local escaped

   case ",${value}," in
      *",${configuration}->"*","*)
         r_escaped_sed_pattern "${configuration}"
         escaped="${RVAL}"

         mapped="`LC_ALL=C sed -n -e "s/.*,${escaped}->\([^,]*\),.*/\\1/p" <<< ",${value},"`"
         if [ -z "${mapped}" ]
         then
         _log_verbose "Configuration \"${configuration}\" skipped due \
to \"${identifier}\""
            return 0
         fi

         _log_verbose "Configuration \"${configuration}\" mapped to \
\"${mapped}\" due to environment variable \"${identifier}\""
         RVAL="${mapped}"
      ;;
   esac
}


craft::path::r_config_extension()
{
   log_entry "craft::path::r_config_extension" "$@"

   local name="$1"

   local identifier

   identifier="MULLE_SOURCETREE_CONFIG_NAME"
   if [ ! -z "${name}" ]
   then
      include "case"

      local base_identifier

      r_smart_upcase_identifier "${name}"
      base_identifier="${RVAL}"

      # figure out the config name of the project, use this as
      # the extension for its definition
      identifier="MULLE_SOURCETREE_CONFIG_NAME_${base_identifier}"
   fi

   local value

   r_shell_indirect_expand "${identifier}"
   value="${RVAL}"

   case "${value}" in
      'config'|'default')
         value=""
      ;;

      *)
         value=".${value}"
      ;;
   esac

   log_verbose "Definition and craftinfo extension is \"${value}\""
   RVAL="${value}"
}



craft::path::r_dependencydir()
{
   log_entry "craft::path::r_dependencydir" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   include "craft::style"

   #
   # Figure out where to dispense into
   #
   craft::style::r_get_sdk_platform_configuration_string "${sdk}" \
                                                         "${platform}" \
                                                         "${configuration}"  \
                                                         "${style}"
   r_filepath_concat "${DEPENDENCY_DIR}" "${RVAL}"
}


craft::path::r_mainproject_kitchendir()
{
   log_entry "craft::path::r_mainproject_kitchendir" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"
   local kitchendir="$5"

   local stylesubdir

   include "craft::style"

   craft::style::r_get_sdk_platform_configuration_string "${sdk}" \
                                                         "${platform}" \
                                                         "${configuration}" \
                                                         "${style}"
   stylesubdir="${RVAL}"

   r_filepath_concat "${kitchendir}" "${stylesubdir}"
}



#
# TODO: prefix MULLE_ prefix on MULLE_SDK_PATH is a bit weird since
# all other flags known by mulle-make do not have a MULLE_ prefix
#
craft::path::r_get_mulle_sdk_path()
{
   log_entry "craft::path::r_get_mulle_sdk_path" "$@"

   local sdk="$1"
   local platform="$2"
   local style="$3"

   local sdk_platform

   include "craft::style"

   craft::style::r_get_sdk_platform_string "${sdk}" "${platform}" "${style}"
   sdk_platform="${RVAL}"

   local addiction_dir
   local dependency_dir

   r_filepath_concat "${ADDICTION_DIR}" "${sdk_platform}"
   addiction_dir="${RVAL}"

   r_filepath_concat "${DEPENDENCY_DIR}" "${sdk_platform}"
   dependency_dir="${RVAL}"

   r_colon_concat "${dependency_dir}" "${addiction_dir}"
   r_colon_concat "${RVAL}" "${MULLE_SDK_PATH}"

   # this will be passed as MULLE_SDK_PATH

   log_debug "sdk_path: ${RVAL}"
}


craft::path::r_name_from_evaledproject()
{
   log_entry "craft::path::r_name_from_evaledproject" "$@"

   local evaledproject="$1"

   [ -z "${evaledproject}" ] && _internal_fail "evaledproject is empty"

   local name
#   log_setting "MULLE_VIRTUAL_ROOT=${MULLE_VIRTUAL_ROOT}"
#   log_setting "MULLE_SOURCETREE_STASH_DIR=${MULLE_SOURCETREE_STASH_DIR}"

   name="${evaledproject#${MULLE_VIRTUAL_ROOT:-${PWD}}/}"
   name="${name#${MULLE_SOURCETREE_STASH_DIR}/}"
   name="${name#${MULLE_SOURCETREE_STASH_DIRNAME:-stash}/}"

   # replace everything thats not an identifier or . _ - + with -
   name="${name//[^a-zA-Z0-9_.+-]/-}"
   name="${name##-}"
   name="${name%%-}"

   [ -z "${name}" ] && _internal_fail "Name is empty from \"${project}\""

   RVAL="${name}"
}


craft::path::r_name_from_project()
{
   log_entry "craft::path::r_name_from_project" "$@"

   local project="$1"

   r_expanded_string "${project}"
   craft::path::r_name_from_evaledproject "${RVAL}"
}


#
# remove any non-identifiers and file extensions from name
#
craft::path::r_build_directory_name()
{
   log_entry "craft::path::r_build_directory_name" "$@"

   r_basename "$1"         # just filename
   RVAL="${RVAL%%.*}"      # remove file extensions
   r_identifier "${RVAL}"  # make identifier (bad chars -> '_')
   RVAL="${RVAL%%_}"       # remove trailing '_'
   RVAL="${RVAL##_}"       # remove leading '_'
}


craft::path::r_effective_project_kitchendir()
{
   log_entry "craft::path::r_effective_project_kitchendir" "$@"

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
         craft::path::r_build_directory_name "${name}"
         directory="${RVAL}"
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
craft::path::__evaluate_variables()
{
   log_entry "craft::path::__evaluate_variables" "$@"

   local project="$1"
   local sdk="$2"
   local platform="$3"
   local configuration="$4"
   # local style="$5"  // unused always relax
   local kitchendir="$6"
   local verify="$7"   # can be left empty

   #
   # getting the project name nice is fairly crucial to figure out when
   # things go wrong. project * happens when we run log command
   #
   if [ "${project}" = '*' ]
   then
      _name="${project}"
      _evaledproject=""
      _configuration="${configuration}"
      log_fluff "Configuration mapping will not be found by logs"
   else
      r_expanded_string "${project}"
      _evaledproject="${RVAL}"
      craft::path::r_name_from_evaledproject "${_evaledproject}"
      _name="${RVAL}"

      craft::path::r_mapped_configuration "${_name}" "${configuration}"
      _configuration="${RVAL}"
   fi

   include "craft::style"

   #
   # this is the build style which is always "relax"
   #
   craft::style::r_get_sdk_platform_configuration_string "${sdk}" \
                                                         "${platform}" \
                                                         "${_configuration}" \
                                                         "relax"
   r_filepath_concat "${kitchendir}" "${RVAL}"

   craft::path::r_effective_project_kitchendir "${_name}" "${RVAL}" "${verify}"
   _kitchendir="${RVAL}"

   log_setting "kitchendir     : \"${_kitchendir}\""
   log_setting "configuration  : \"${_configuration}\""
   log_setting "evaledproject  : \"${_evaledproject}\""
   log_setting "name           : \"${_name}\""
}
