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
# A prototypical, opt-in *shared* dependency store for mulle-craft.
#
# Normally every project crafts its own dependencies into its own
# DEPENDENCY_DIR. When releasing many repositories that share dependencies,
# the very same dependency is built once per project (and once per
# configuration). This module lets those builds be shared.
#
# It is OFF by default. Set MULLE_CRAFT_SHARED_DEPENDENCY_DIR to a directory
# *outside* of all projects to enable it, e.g.
#
#    MULLE_CRAFT_SHARED_DEPENDENCY_DIR="${HOME}/.mulle/var/cache/sde/shared/dependency"
#
# A crafted node is captured as the set of files it added to (or changed in)
# the current dependency directory and stored under a key derived from the
# node identity (name, source revision, configuration, platform, sdk, style,
# toolchain and marks). A later project with the same key restores the files
# instead of building them again.
#
# Environment:
#    MULLE_CRAFT_SHARED_DEPENDENCY_DIR : store root (empty => disabled)
#    MULLE_CRAFT_SHARED_DRY_RUN        : YES => report hits, but do not restore
#    MULLE_CRAFT_SHARED_FLAVOR         : optional extra key component, use to
#                                        force a global re-build for a release
#
# Enabling it:
#    A bare `export MULLE_CRAFT_SHARED_DEPENDENCY_DIR=...` reaches mulle-craft
#    when you call mulle-craft directly, but NOT when you go through
#    mulle-sde (which builds its environment from the project definitions and
#    drops unknown shell variables). There, use either
#
#       mulle-sde -DMULLE_CRAFT_SHARED_DEPENDENCY_DIR=<dir> craft
#
#    or persist it in the environment:
#
#       mulle-sde env set MULLE_CRAFT_SHARED_DEPENDENCY_DIR <dir>
#
# Measuring the hit rate:
#    Every decision is appended to "<store>/.events" as
#       HIT|MISS|BUSY|SKIP;<name>;<key>
#    so e.g. `grep -c '^HIT;' <store>/.events` gives the number of builds that
#    were avoided. A summary is logged at the end of every craftorder run.
#
# Cleaning:
#    The shared store is deliberately NOT removed by "clean tidy" or
#    "gravetidy". Remove it explicitly with
#       mulle-craft clean shared-dependency-store
#       mulle-sde clean shared
#
# NOTE: This is a prototype. The key does not (yet) fold in the revisions of
# transitive dependencies. Use MULLE_CRAFT_SHARED_FLAVOR per release, or
# `mulle-craft clean shared-dependency-store`, when in doubt.
#
MULLE_CRAFT_STORE_SH='included'


#
# returns 0 if the shared store should be consulted for this process
#
craft::store::is_enabled()
{
   [ -z "${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}" ] && return 1
   [ "${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}" = 'NO' ] && return 1

   #
   # parallel/multiphase builds concurrently write into the same dependency
   # directory, so we can not cheaply diff them. Disable for those.
   #
   [ ! -z "${PARALLEL_PHASE:-}" ] && return 1

   return 0
}


craft::store::r_store_dir()
{
   r_absolutepath "${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}"
   RVAL="${RVAL}"
}


craft::store::r_node_dir()
{
   local key="$1"

   craft::store::r_store_dir
   r_filepath_concat "${RVAL}" "${key}"
}


craft::store::has()
{
   [ -f "$1/.complete" ]
}


#
# Derive a filesystem friendly key from what can influence the produced
# artifacts. Returns 1 (RVAL holds the reason) when the node must not be
# shared. Namely: symlinked/local checkouts, subprojects (no-memo) and
# checkouts without a clean git revision.
#
craft::store::r_node_key()
{
   local project="$1"
   local name="$2"
   local marks="$3"
   local sdk="$4"
   local platform="$5"
   local configuration="$6"
   local style="$7"
   local toolchain="$8"

   case ",${marks}," in
      *',no-memo,'*)
         RVAL="no-memo"
         return 1
      ;;
   esac

   if [ -L "${project}" ]
   then
      RVAL="symlink"
      return 1
   fi

   if [ ! -d "${project}/.git" ]
   then
      RVAL="no-git"
      return 1
   fi

   local rev

   rev="`git -C "${project}" rev-parse HEAD 2> /dev/null`" || rev=""
   if [ -z "${rev}" ]
   then
      RVAL="no-rev"
      return 1
   fi

   local dirty

   dirty="`git -C "${project}" status --porcelain 2> /dev/null`"
   if [ ! -z "${dirty}" ]
   then
      RVAL="dirty"
      return 1
   fi

   # name is already sanitized by craft::path::r_name_from_evaledproject
   local sname

   r_basename "${name}"
   sname="${RVAL}"

   local variant

   variant="${marks};;${style};;${toolchain};;${MULLE_CRAFT_SHARED_FLAVOR:-}"
   r_fnv1a_32 "${variant}"
   printf -v variant "%08x" "${RVAL}"

   RVAL="${sname}/${configuration}--${platform}--${sdk}/${rev}/${variant}"
   return 0
}


craft::store::_protect()
{
   case "${MULLE_UNAME:-}" in
      'windows'|'mingw'|'msys')
         return 0
      ;;
   esac

   exekutor chmod -R a-w "$1" || return 1
}


#
# write a sorted list of the relative paths of all regular files below dir
#
craft::store::_write_manifest()
{
   local dir="$1"
   local outputfile="$2"

   if [ ! -d "${dir}" ]
   then
      : > "${outputfile}"
      return 0
   fi

   (
      cd "${dir}" &&
      find . -type f
   ) | sed -e 's|^\./||' | LC_ALL=C sort > "${outputfile}"
}


craft::store::_changed_paths()
{
   local beforefile="$1"
   local afterfile="$2"
   local newerfile="$3"
   local outputfile="$4"

   # paths that appeared (covers copied files that kept an old mtime)
   LC_ALL=C comm -13 "${beforefile}" "${afterfile}" > "${outputfile}"

   # paths that were touched during the build (covers in-place changes)
   if [ -s "${newerfile}" ]
   then
      cat "${newerfile}" >> "${outputfile}"
   fi

   LC_ALL=C sort -u "${outputfile}" -o "${outputfile}"
}


#
# Restore a previously captured node into the project dependency directory.
#
craft::store::restore()
{
   log_entry "craft::store::restore" "$@"

   local dependencydir="$1"
   local nodedir="$2"

   local filesdir

   filesdir="${nodedir}/files"
   if [ ! -d "${filesdir}" ]
   then
      return 0
   fi

   mkdir_if_missing "${dependencydir}"

   if ! (
      cd "${filesdir}" &&
      "${TAR:-tar}" -cf - .
   ) | (
      cd "${dependencydir}" &&
      "${TAR:-tar}" -xf -
   )
   then
      return 1
   fi

   #
   # the store is protected (read-only), make the restored files writable
   # again so that subsequent nodes can replace them. The dependency dir is
   # write protected as a whole at the end of the craft anyway.
   #
   case "${MULLE_UNAME:-}" in
      'windows'|'mingw'|'msys')
      ;;

      *)
         exekutor chmod -R u+w "${dependencydir}" 2> /dev/null || true
      ;;
   esac

   return 0
}


craft::store::claim()
{
   local nodedir="$1"
   local lockdir

   lockdir="${nodedir}.lock"
   mkdir_if_missing "${lockdir%/*}"

   mkdir "${lockdir}" 2> /dev/null
}


craft::store::release()
{
   local nodedir="$1"

   rmdir "${nodedir}.lock" 2> /dev/null || true
}


#
# Capture the files a node contributed to dependencydir into the store.
# `beforefile` is a manifest taken before the build, `stampfile` a file
# touched just before the build (for find -newer).
#
craft::store::capture()
{
   log_entry "craft::store::capture" "$@"

   local dependencydir="$1"
   local nodedir="$2"
   local beforefile="$3"
   local stampfile="$4"

   [ -z "${nodedir}" ] && return 1

   local afterfile
   local newerfile
   local changedfile

   _r_make_tmp_in_dir "${KITCHEN_DIR}" ".store-after" "f" || return 1
   afterfile="${RVAL}"
   _r_make_tmp_in_dir "${KITCHEN_DIR}" ".store-newer" "f" || return 1
   newerfile="${RVAL}"
   _r_make_tmp_in_dir "${KITCHEN_DIR}" ".store-changed" "f" || return 1
   changedfile="${RVAL}"

   craft::store::_write_manifest "${dependencydir}" "${afterfile}"

   : > "${newerfile}"
   if [ -d "${dependencydir}" ]
   then
      (
         cd "${dependencydir}" &&
         find . -type f -newer "${stampfile}"
      ) | sed -e 's|^\./||' > "${newerfile}"
   fi

   craft::store::_changed_paths "${beforefile}" \
                                "${afterfile}" \
                                "${newerfile}" \
                                "${changedfile}"

   local filesdir

   filesdir="${nodedir}/files"
   rmdir_safer "${filesdir}"
   mkdir_if_missing "${nodedir}"

   local count
   local rel
   local reldir

   count=0
   while IFS= read -r rel
   do
      [ -z "${rel}" ] && continue

      reldir="${rel%/*}"
      if [ "${reldir}" = "${rel}" ]
      then
         mkdir_if_missing "${filesdir}"
      else
         mkdir_if_missing "${filesdir}/${reldir}"
      fi

      cp "${dependencydir}/${rel}" "${filesdir}/${rel}" || return 1
      count=$(( count + 1 ))
   done < "${changedfile}"

   redirect_exekutor "${nodedir}/.complete" printf "%s\n" "${count}"

   craft::store::_protect "${nodedir}" || return 1
   return 0
}


craft::store::log_event()
{
   local event="$1"
   local name="$2"
   local detail="${3:-}"

   mkdir_if_missing "${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}"

   redirect_append_exekutor "${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}/.events" \
      printf "%s;%s;%s\n" "${event}" "${name}" "${detail}"

   log_verbose "Shared store: ${event} ${name}${detail:+ (${detail})}"
}


craft::store::print_summary()
{
   craft::store::is_enabled || return 0

   local eventsfile

   eventsfile="${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}/.events"
   [ -f "${eventsfile}" ] || return 0

   local hits
   local misses
   local skips
   local busys

   hits="`grep -c '^HIT;' "${eventsfile}" 2> /dev/null || true`"
   misses="`grep -c '^MISS;' "${eventsfile}" 2> /dev/null || true`"
   skips="`grep -c '^SKIP;' "${eventsfile}" 2> /dev/null || true`"
   busys="`grep -c '^BUSY;' "${eventsfile}" 2> /dev/null || true`"

   log_info "Shared store: hits=${hits:-0} misses=${misses:-0} skipped=${skips:-0} busy=${busys:-0} (${eventsfile})"
}


craft::store::remove()
{
   log_entry "craft::store::remove" "$@"

   [ -z "${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}" ] && return 0

   craft::store::r_store_dir
   if [ -d "${RVAL}" ]
   then
      log_verbose "Cleaning shared dependency store \"${RVAL}\""
      chmod -R u+w "${RVAL}" 2> /dev/null || true
      rmdir_safer "${RVAL}"
   fi
}


: 
