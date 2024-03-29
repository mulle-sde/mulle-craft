# shellcheck shell=bash
# shellcheck disable=SC2236
# shellcheck disable=SC2166
# shellcheck disable=SC2006
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
MULLE_CRAFT_QUALIFIER_SH='included'


craft::qualifier::usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} qualifier [options] <print|match> [marks]

   Print the craftorder qualifier that will be used. You can also match it
   against a list of marks. This qualifier will be used by mulle-craft with
   mulle-sourcetree walk --qualifier option to filter the craftorder.

Examples:
      ${MULLE_USAGE_NAME} qualifier --platform linux print
      ${MULLE_USAGE_NAME} qualifier --platform linux match only-os-darwin
      mulle-sourcetree walk --qualifier "\`${MULLE_USAGE_NAME} qualifier --no-lf\`" \
         'printf "%s\n" "${WALK_INDENT}${NODE_ADDRESS} ${NODE_MARKS}"'

Options:
   --configuration <name> : set configuration (Debug)
   --debug                : set configuration to "Debug"
   --platform <name>      : set platform (${MULLE_UNAME})
   --release              : set configuration to "Release"
   --sdk <name>           : set SDK for (Default)
   --no-lf                : replace output linefeeds with space
EOF
  exit 1
}


craft::qualifier::r_determine_platform_sdk_version()
{
   log_entry "craft::qualifier::r_determine_platform_sdk_version" "$@"

   local sdk="${1:-Default}"
   local platform="${2:-${MULLE_UNAME}}"
   local version="${3:-DEFAULT}"

   #
   # version is only used for the default SDK on the default platform
   #
   case "${version}" in
      DEFAULT)
         RVAL=
         if [ "${platform}" = "${MULLE_UNAME}" -a "${sdk}" = "Default" ]
         then
            case "${platform}" in
               'darwin')
                  RVAL="`rexekutor sw_vers -productVersion`"
               ;;
            esac
         fi
      ;;

      *)
         RVAL="${version}"
      ;;
   esac
}


#
# TODO: all marks used here should be of the form craftorder-* ?
#
craft::qualifier::r_craftorder_qualifier()
{
   log_entry "craft::qualifier::r_craftorder_qualifier" "$@"

   local sdk="${1:-Default}"
   local platform="${2:-Default}"
   local configuration="${3:-Debug}"
   local version="$4"

   r_lowercase "${sdk}"
   sdk="${RVAL}"

   r_lowercase "${platform}"
   platform="${RVAL}"

   r_lowercase "${configuration}"
   configuration="${RVAL}"

   r_lowercase "${version}"
   version="${RVAL}"

   if [ "${platform}" = 'default' ]
   then
      platform="${MULLE_UNAME}"
   fi

   local clause

   # default is not really matchable, as we don't know what it is, yet
   # query is needed to avoid pulling in musl or cosmopolitan here
   clause="ENABLES craft-sdk-${sdk}"

   local qualifier

   r_concat "${qualifier}" "${clause}" $'\n'"AND "
   qualifier="${RVAL}"

   # also check the global platform flag
   clause="ENABLES platform-${platform}"

   r_concat "${qualifier}" "${clause}" $'\n'"AND "
   qualifier="${RVAL}"

   # now check craft-specific flags, sdk and configuration are only
   # interesting for craft, so there aren't global versions      
   clause="ENABLES craft-platform-${platform}"
   r_concat "${qualifier}" "${clause}" $'\n'"AND "
   qualifier="${RVAL}"

   # configuration can't be empty
   clause="ENABLES craft-configuration-${configuration}"

   r_concat "${qualifier}" "${clause}" $'\n'"AND "
   qualifier="${RVAL}"

   #
   # figure out current version. version of what though ? should be the
   # sdk really
   #
   # if [ -z "${version}" ]
   # then
   #    case "${MULLE_UNAME}" in
   #       darwin)
   #          version="`rexekutor sw_vers -productVersion`" || exit 1
   #       ;;
   #    esac
   # fi

   if [ ! -z "${version}" ]
   then
      # the version check for a Default SDK checks the platform,
      # but version must be provided
      local match_version

      match_version="${sdk}"
      if [ "${match_version}" = "default" ]
      then
         match_version="${platform}"
      fi

      if [ ! -z "${version}" ]
      then
         clause="\
(VERSION version-min-${match_version} <= ${version} \
 AND VERSION version-max-${match_version} >= ${version})"

         r_concat "${RVAL}" "${clause}" $'\n'"AND "
         qualifier="${RVAL}"
      fi
   fi

   RVAL="${qualifier}"
}


craft::qualifier::r_filtered_craftorder()
{
   log_entry "craft::qualifier::r_filtered_craftorder" "$@"

   local craftorder="$1"
   local sdk="$2"
   local platform="$3"
   local configuration="$4"
   local version="$5"

   include "sourcetree::marks"

   local qualifier

   r_concat "MATCHES build" "MATCHES build-os-${MULLE_UNAME}" $'\n'"AND "
   qualifier="${RVAL}"

   craft::qualifier::r_craftorder_qualifier "${sdk}" \
                                            "${platform}" \
                                            "${configuration}" \
                                            "${version}"

   r_concat "${qualifier}" "${RVAL}" $'\n'"AND "
   qualifier="${RVAL}"

   local line
   local result
   local marks

   result=
   .foreachline line in ${craftorder}
   .do
      marks="${line#*;}"

      if sourcetree::marks::filter_with_qualifier "${marks}" "${qualifier}"
      then
         r_add_line "${result}" "${line}"
         result="${RVAL}"
      fi
   .done

   RVAL="${result}"
}



craft::qualifier::main()
{
   log_entry "craft::qualifier::main" "$@"

   local OPTION_CONFIGURATION
   local OPTION_PLATFORM
   local OPTION_SDK
   local OPTION_VERSION
   local OPTION_LF

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            craft::qualifier::usage
         ;;

         --release)
            OPTION_CONFIGURATION="Release"
         ;;

         --debug)
            # Release is fallback for Debug
            OPTION_CONFIGURATION="Debug"
         ;;

         --lf)
            OPTION_LF='YES'
         ;;

         --no-lf)
            OPTION_LF='NO'
         ;;

         --configuration)
            [ $# -eq 1 ] && craft::qualifier::usage "Missing argument to \"$1\""
            shift

            OPTION_CONFIGURATION="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && craft::qualifier::usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         --sdk)
            [ $# -eq 1 ] && craft::qualifier::usage "Missing argument to \"$1\""
            shift

            OPTION_SDK="$1"
         ;;

         --version)
            [ $# -eq 1 ] && craft::qualifier::usage "Missing argument to \"$1\""
            shift

            OPTION_VERSION="$1"
         ;;

         -*)
            craft::qualifier::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   if ! [ -z "${OPTION_VERSION}" ] &&
        [ "${OPTION_PLATFORM:-${MULLE_UNAME}}" != "${MULLE_UNAME}" -o \
          "${OPTION_SDK:-Default}" != "Default" ]
   then
      log_warning "Version will be ignored for non-host platforms an non-default SDK"
   fi

   local version

   craft::qualifier::r_determine_platform_sdk_version "${OPTION_SDK}" \
                                                      "${OPTION_PLATFORM}" \
                                                      "${OPTION_VERSION}"
   version="${RVAL}"

   local no_build_qualifier

   craft::qualifier::r_craftorder_qualifier "${OPTION_SDK}" \
                                            "${OPTION_PLATFORM}" \
                                            "${OPTION_CONFIGURATION}" \
                                            "${version}"
   no_build_qualifier="${RVAL}"

   local qualifier

   r_concat "MATCHES build" "${no_build_qualifier}" $'\n'"AND "
   qualifier="${RVAL}"

   case "$1" in
      print)
         shift
      ;;

      print-no-build)
         shift
         RVAL="${no_build_qualifier}"
      ;;

      match)
         [ $# -lt 2 ] && craft::qualifier::usage "Missing argument for $1"
         [ $# -gt 2 ] && shift 2 && craft::qualifier::usage "Superflous arguments \"$*\""
         shift

         local marks
         local warn

         # do a couple of santity checks on version if provided
         marks="$1"
         warn=NO

         case ",${marks}," in
            *,version-min-*,*)
               case ",${marks}," in
                  *,version-max-*,*)
                  ;;

                  *)
                     warn='YES'
                  ;;
               esac
            ;;

            *,version-max-*,*)
               warn='YES'
            ;;
         esac

         if [ "${warn}" = 'YES' ]
         then
            _log_warning "warning: version-min-${OPTION_PLATFORM:-${MULLE_UNAME}} needs \
version-max-${OPTION_PLATFORM:-${MULLE_UNAME}} to work and vice versa"
         fi

         include "sourcetree::marks"

         if sourcetree::marks::filter_with_qualifier "${marks}" "${qualifier}"
         then
            log_info 'YES'
            return 0
         fi
         log_info 'NO'
         return 1
      ;;

      version)
         if [ -z "${version}" ]
         then
            log_error "No version found"
            return 1
         fi
         printf "%s\n" "${version}"
         return 0
      ;;
   esac

   [ $# -eq 0 ] || craft::qualifier::usage "Superflous arguments \"$*\""

   if [ "${OPTION_LF}" = 'NO' ]
   then
      RVAL="${RVAL//$'\n'/ }"
   fi
   printf "%s\n" "${RVAL}"
}

:
