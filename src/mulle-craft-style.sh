#! /usr/bin/env bash
#
#   Copyright (c) 2021 Nat! - Mulle kybernetiK
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
MULLE_CRAFT_STYLE_SH="included"


craft_craftorder_style_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} style [options] 

   Print the subfolder used for the dispensal of craft products into the 
   "dependency" folder. With a style you can control, if a craft for 
   "configuration" 'Release' will overwrite a previous craft for 'Debug' 
   ("style"='none') or are kept side by side (any of the others).

   Other possibly distinctions besides "configuration" are "sdk" and 
   "platform".

Styles:
      none      : no intermediate folders
      auto      : auto is like relax, but suppresses Release in the output
      relax     : relax will not emit the platform name, if identical to host
      strict    : emit everything as two folders
      tight     : like strict but uses only one folder
      i-<style> : like athe non i- counterpart with the order reversed

Options:
   --style <s>          : dispense style (auto)
   --sdk <sdk>          : the SDK to craft with (Default)
   --platform <p>       : the platform to craft for (${MULLE_UNAME})
   --configuration <c>  : configuration to craft  (Debug)

EOF
  exit 1
}


r_get_sdk_platform_style_string()
{
   log_entry "r_get_sdk_platform_style_string" "$@"

   local sdk="$1"
   local platform="$2"
   local style="$3"

   [ -z "${sdk}" ]        && internal_fail "sdk must not be empty"
   [ -z "${platform}" ]   && internal_fail "platform must not be empty"
   [ -z "${style}" ]      && internal_fail "style must not be empty"

   if [ "${platform}" = 'Default' ]
   then
      platform="${MULLE_UNAME}"
   fi

   case "${style}" in
      none|i-none)
         RVAL=
      ;;

      strict)
         RVAL="${sdk}-${platform}"
      ;;

      i-strict)
         RVAL="${platform}-${sdk}"
      ;;

      auto|relax|tight)
         if [ "${sdk}" = "Default" ]
         then
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL=""
            else
               RVAL="${platform}"
            fi
         else
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL="${sdk}"
            else
               RVAL="${sdk}-${platform}"
            fi
         fi
      ;;

      i-auto|i-relax|i-tight)
         if [ "${sdk}" = "Default" ]
         then
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL=""
            else
               RVAL="${platform}"
            fi
         else
            if [ "${platform}" = "${MULLE_UNAME}" ]
            then
               RVAL="${sdk}"
            else
               RVAL="${platform}-${sdk}"
            fi
         fi
      ;;


      *)
         fail "Unknown dispense style \"${style}\""
      ;;
   esac
}


#
# Note:  build directories are always like relax dispense-style
#        this is relevant for dispensing
#
# TODO: make style a formatter, so ppl can chose arbitrarily
#
r_get_sdk_platform_configuration_style_string()
{
   log_entry "r_get_sdk_platform_configuration_style_string" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local style="$4"

   r_get_sdk_platform_style_string "${sdk}" "${platform}" "${style}"
   case "${style}" in
      i-tight)
         r_filepath_concat "${configuration}-${RVAL}"
      ;;

      i-strict|i-relax)
         r_filepath_concat "${configuration}" "${RVAL}"
      ;;

      i-auto)
         if [ "${configuration}" != "Release" ]
         then
            r_filepath_concat "${configuration}" "${RVAL}"
         fi
      ;;

      tight)
         r_filepath_concat "${RVAL}-${configuration}"
      ;;

      strict|relax)
         r_filepath_concat "${RVAL}" "${configuration}"
      ;;

      auto)
         if [ "${configuration}" != "Release" ]
         then
            r_filepath_concat "${RVAL}" "${configuration}"
         fi
      ;;
   esac
}


craft_craftorder_style_main()
{
   log_entry "craft_craftorder_style_main" "$@"

   local OPTION_LOCAL_CRAFTINFO='YES'
   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_SDK='Default'
   local OPTION_CONFIGURATION='Debug'
   local OPTION_STYLE='auto'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft_craftorder_search_usage
         ;;

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft_craftorder_style_usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft_craftorder_style_usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft_craftorder_style_usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         --style)
            [ $# -eq 1 ] && craft_craftorder_style_usage "Missing argument to \"$1\""
            shift

            OPTION_STYLE="$1"
         ;;

         -*)
            craft_craftorder_search_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   r_get_sdk_platform_configuration_style_string "${OPTION_SDK}" \
                                                 "${OPTION_PLATFORM}" \
                                                 "${OPTION_CONFIGURATION}" \
                                                 "${OPTION_STYLE}" 
   if [ -z "${RVAL}" ]
   then
      log_info "Style output is empty"
   else
      echo "${RVAL}"
   fi
}



r_craft_shared_donefile()
{
   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   RVAL="${ADDICTION_DIR}/etc/craftorder-${sdk}--${platform}--${configuration}"
}


r_craft_donefile()
{
   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   RVAL="${DEPENDENCY_DIR}/etc/craftorder-${sdk}--${platform}--${configuration}"
}


#   local _donefile
#   local _shared_donefile
__craft_have_donefiles()
{
   log_entry "__craft_have_donefiles" "$@"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"

   #
   # the donefile is stored in a different place then the
   # actual buildir because that's to be determined later
   # at least for now
   #
   local have_a_donefile

   r_craft_shared_donefile "${sdk}" "${platform}" "${configuration}"
   _shared_donefile="${RVAL}"

   r_craft_donefile "${sdk}" "${platform}" "${configuration}"
   _donefile="${RVAL}"

   local have_a_donefile

   have_a_donefile="NO"
   if [ -f "${_donefile}" ]
   then
      log_fluff "A donefile \"${_donefile#${MULLE_USER_PWD}/}\" is present"
      have_a_donefile='YES'
      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_trace2 "donefile: `cat "${_donefile}"`"
      fi
   else
      r_mkdir_parent_if_missing "${_donefile}"
   fi

   if [ -f "${_shared_donefile}" ]
   then
      log_verbose "A shared donefile \"${_shared_donefile#${MULLE_USER_PWD}/}\" is present"
      have_a_donefile='YES'
      if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
      then
         log_trace2 "shared donefile: `cat "${_shared_donefile}"`"
      fi
   else
      log_fluff "There is no shared donefile \"${_shared_donefile#${MULLE_USER_PWD}/}\""
   fi

   [ "${have_a_donefile}" = 'YES' ]
}


#
# local _configuration
# local _evaledproject
# local _name
#
r_mapped_configuration()
{
   log_entry "r_mapped_configuration" "$@"

   local name="$1"
   local configuration="$2"

   if [ -z "${MULLE_CASE_SH}" ]
   then
     . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-case.sh" || exit 1
   fi

   local base_identifier

   r_tweaked_de_camel_case "${name}"
   r_uppercase "${RVAL}"
   r_identifier "${RVAL}"
   base_identifier="${RVAL}"

   #
   # Map some configurations (e.g. Debug -> Release for mulle-objc-runtime)
   # You can also map to empty, to skip a configuration
   #
   local value
   local identifier

   identifier="MULLE_CRAFT_${base_identifier}_MAP_CONFIGURATIONS"
   if [ ! -z "${ZSH_VERSION}" ]
   then
      value="${(P)identifier}"
   else
      value="${!identifier}"
   fi

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
         log_verbose "Configuration \"${configuration}\" skipped due \
to \"${identifier}\""
            return 0
         fi

         log_verbose "Configuration \"${configuration}\" mapped to \
\"${mapped}\" due to environment variable \"${identifier}\""
         RVAL="${mapped}"
      ;;
   esac
}



r_name_from_evaledproject()
{
   log_entry "r_name_from_evaledproject" "$@"

   local evaledproject="$1"

   [ -z "${evaledproject}" ] && internal_fail "evaledproject is empty"

   local name
#   log_trace2 "MULLE_VIRTUAL_ROOT=${MULLE_VIRTUAL_ROOT}"
#   log_trace2 "MULLE_SOURCETREE_STASH_DIR=${MULLE_SOURCETREE_STASH_DIR}"

   name="${evaledproject#${MULLE_VIRTUAL_ROOT:-${PWD}}/}"
   name="${name#${MULLE_SOURCETREE_STASH_DIRNAME:-stash}/}"

   # replace everything thats not an identifier or . _ - + with -
   name="${name//[^a-zA-Z0-9_.+-]/-}"
   name="${name##-}"
   name="${name%%-}"

   [ -z "${name}" ] && internal_fail "Name is empty from \"${project}\""

   RVAL="${name}"
}


r_name_from_project()
{
   log_entry "r_name_from_project" "$@"

   local project="$1"

   r_expanded_string "${project}"
   r_name_from_evaledproject "${RVAL}"
}


#
# remove any non-identifiers and file extensions from name
#
r_build_directory_name()
{
   log_entry "r_build_directory_name" "$@"

   r_basename "$1"         # just filename
   RVAL="${RVAL%%.*}"      # remove file extensions
   r_identifier "${RVAL}"  # make identifier (bad chars -> '_')
   RVAL="${RVAL%%_}"       # remove trailing '_'
   RVAL="${RVAL##_}"       # remove leading '_'
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
         r_build_directory_name "${name}"
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
# TODO: prefix MULLE_ prefix on MULLE_SDK_PATH is a bit weird since
# all other flags known by mulle-make do not have a MULLE_ prefix
#
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
      r_name_from_evaledproject "${_evaledproject}"
      _name="${RVAL}"

      r_mapped_configuration "${_name}" "${configuration}"
      _configuration="${RVAL}"
   fi

   #
   # this is the build style which is always "relax"
   #
   r_get_sdk_platform_configuration_style_string "${sdk}" \
                                                 "${platform}" \
                                                 "${_configuration}" \
                                                 "relax"
   r_filepath_concat "${kitchendir}" "${RVAL}"
   r_effective_project_kitchendir "${_name}" "${RVAL}" "${verify}"
   _kitchendir="${RVAL}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "kitchendir     : \"${_kitchendir}\""
      log_trace2 "configuration  : \"${_configuration}\""
      log_trace2 "evaledproject  : \"${_evaledproject}\""
      log_trace2 "name           : \"${_name}\""
   fi
}


r_craft_mainproject_kitchendir()
{
   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   shift 3
   local kitchendir="$1"

   local stylesubdir

   r_get_sdk_platform_configuration_style_string "${sdk}" \
                                                 "${platform}" \
                                                 "${configuration}" \
                                                 "relax"
   stylesubdir="${RVAL}"

   r_filepath_concat "${kitchendir}" "${stylesubdir}"
}


craft_craftorder_donefiles_main()
{
   log_entry "craft_craftorder_donefiles_main" "$@"

   local OPTION_PLATFORM="Default"
   local OPTION_SDK='Default'
   local OPTION_CONFIGURATION='Debug'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft_craftorder_search_usage
         ;;

         #
         # quadruple of sdk/platform/configuration/style
         #
         --configuration)
            [ $# -eq 1 ] && craft_craftorder_style_usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft_craftorder_style_usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft_craftorder_style_usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         -*)
            craft_craftorder_search_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   r_craft_donefile "${OPTION_SDK}" "${OPTION_PLATFORM}" "${OPTION_CONFIGURATION}"
   log_info "Donefile: ${C_RESET_BOLD}${RVAL#${MULLE_USER_PWD}/}"

   r_craft_shared_donefile "${OPTION_SDK}" "${OPTION_PLATFORM}" "${OPTION_CONFIGURATION}"
   log_info "Shared donefile: ${C_RESET_BOLD}${RVAL#${MULLE_USER_PWD}/}"
}


