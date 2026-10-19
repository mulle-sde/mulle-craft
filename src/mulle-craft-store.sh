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
# An opt-in *shared* dependency store for mulle-craft.
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
# LAYERS
# ------
# One store is the special case of a *layer*. Set
# MULLE_CRAFT_SHARED_DEPENDENCY_PATH to a colon separated list of store roots:
#
#    MULLE_CRAFT_SHARED_DEPENDENCY_PATH="${HOME}/.mulle/var/cache/sde/release-0.31/shared:${HOME}/.mulle/var/cache/sde/release-0.31/scratch"
#
# A node is looked up in every layer; the LAST layer that has it wins, so that
# what the current run built beats a stale base. Only the LAST layer is ever
# written to, a missing node is built once and published there. Every other
# layer is read-only, it is just picked from. Projects of "common fate" (one
# release, one product family, one CI job) thus share one writable layer while
# picking from sturdier layers that were populated before.
#
# A layer that must never be written to can say so by placing a ".read-only"
# file in its root. The store then refuses to publish into it and "clean"
# leaves it alone. (The writable layer is the last one by convention; marking
# it read-only turns the whole store into a pure consumer.)
#
# An entry is one gzipped tar archive per node. The readable part of the path
# is the sdk, platform and configuration; everything else that changes the
# produced bytes (the source revision, the working tree contents when the
# checkout has local modifications, marks, style, toolchain, flavor and the
# defines/CFLAGS that are not standard) is folded into a short hash:
#
#    <layer>/<name>/<sdk>-<platform>-<configuration>-<hash>.tgz
#    <layer>/<name>/<sdk>-<platform>-<configuration>-<hash>.prefix
#    <layer>/<name>/<sdk>-<platform>-<configuration>-<hash>.needed
#
# The products are archived exactly as the build installed them, so nothing is
# inferred by diffing the merged dependency directory (which could not see
# empty directories and could not tell a rewritten file from an untouched one).
#
# Publishing is atomic: the archive is written under a temporary name and then
# renamed, so the mere existence of the ".tgz" means the entry is complete. The
# ".prefix" sidecar records the prefix the products were built with, but it is
# only written when the products actually carry that prefix in .pc/.la contents
# (see _tree_has_prefix); a relocatable entry has no sidecar and needs no
# rewriting. When it is written, it happens before the archive is renamed into
# place, so a reader never sees the archive without it.
#
# Absolute paths in pkg-config (.pc) and libtool (.la) metadata are rewritten
# from that recorded prefix to where the archive is unpacked, because the
# prefix baked in at build time is the builder's staging directory and would be
# wrong (or, across machines, non-existent) otherwise. CMake package configs
# derive their prefix from their own location and are relocatable already.
#
# Per node the flow is: if an archive exists (in any layer) unpack it into the
# dependency directory; otherwise, if there is a writable layer, build into a
# private staging directory, archive it into the writable layer and then unpack
# what was just published; otherwise build straight into the dependency
# directory. Dependencies that need "no-inplace" (dispense) handling are never
# shared, there must be no such thing in the store.
#
# What the user sees is one line per node that was not built, naming the layer
# it was picked from:
#
#    Copy mulle-allocator from shared store (~/.mulle/var/cache/sde/shared) [Default-linux-Debug]
#
# so the saving is attributable to the node it happened for, and in a layered
# store it is visible which layer answered (the path is abbreviated, see
# r_layer_display). The trailing bracket names the sdk/platform/configuration
# the entry is for, because a node is stored once per each of those: a native
# and a cross build otherwise print the very same line twice.
#
# The hit/miss bookkeeping is verbose (-v) and the event log.
#
# RESOLUTION (why the key is not just the node)
# ---------------------------------------------
# Two workspaces can build the same node from the same revision with the same
# settings and still get different products: what a declared dependency
# resolves to depends on the *graph*.
#
# A project that declares "mulle-allocator" gets DT_NEEDED libmulle-allocator.so
# in a mulle-c graph, where mulle-allocator is a node of its own. In a graph
# that contains the mulle-core amalgamation it is a constituent of that
# amalgamation, mulle-sourcetree removes the standalone node from the craftorder
# (sourcetree::craftorder::r_remove_amalgamated) and everything links against
# libmulle-core.so instead.
#
# So the key of every node of a run also carries the resolution decisions of its
# craftorder (craft::store::r_craftorder_providers): the "<name>=<provider>"
# pairs of the names that are shadowed by an amalgamation present in this graph.
# A graph without amalgamations adds nothing (the common case), and because the
# shadowing changes the products of the nodes that *use* the shadowed name as
# well, the same salt is folded into every key of the run. It is computed once
# by craft::build::_do_craftorder, which hands it to r_node_key (as
# MULLE_CRAFT_STORE_PROVIDERS) and the nodes it knows to the ".needed" check (as
# MULLE_CRAFT_STORE_NODES).
#
# TOPOLOGY (the backstop)
# -----------------------
# What the key still can not know is the revision of a dependency: a node whose
# source is unchanged still has to be rebuilt when a library it is linked
# against changed. For that the ".needed" sidecar records at capture time which
# libraries of *this* dependency directory the products need at load time, and
# an entry is only served when all of them are present there or will be
# provided by a node of this craftorder (craft::store::entry::is_usable).
# Otherwise the entry is passed over and the node is built here and published
# into the writable layer, which then shadows the unusable entry - the build
# heals itself. Nothing is recorded when no tool can read the requirements
# (readelf/objdump/otool) or when the products need nothing of the dependency
# directory, which is the common case for a static library.
#
# When that happens the user is told, because a node that the store visibly
# holds and that is built anyway needs an explanation:
#
#    The shared store has mulle-testallocator only in a form that does not fit
#    here: it needs libmulle-allocator.so.9, which this dependency directory
#    does not provide. Built here instead and published into the writable layer.
#
# CONCURRENCY (one builder per entry)
# -----------------------------------
# Before a node is built the store claims its entry with an atomic mkdir on the
# lock directory "<entry>.lock". Whoever does not get the claim reports BUSY and
# builds the node into its own dependency directory without publishing it: the
# store is an optimisation, never a reason to wait or to fail.
#
# The claim records its owner ("<host>;<pid>;<epoch>" in "<entry>.lock/owner"),
# and a claim whose owner is provably gone is broken by the next run
# (craft::store::is_lock_stale). Without that a build that was killed - or one
# that failed, see craft::build::build_craftorder_node - would make its entry
# unshareable for everyone forever. A dead owner is only believed when it was
# recorded on this host, a pid means nothing on another machine.
#
# Environment:
#    MULLE_CRAFT_STORE_LOCK_STALE_SECONDS : break a claim whose owner cannot be
#                                         judged (another host, or no owner
#                                         file) after this many seconds
#                                         (default 1800)
#    MULLE_CRAFT_SHARED_DEPENDENCY_PATH : colon separated layers, first is
#                                        read first, last is written (wins
#                                        over _DIR)
#    MULLE_CRAFT_SHARED_DEPENDENCY_DIR  : single layer (compatibility)
#    MULLE_CRAFT_SHARED_DRY_RUN         : YES => report hits, but do not restore
#    MULLE_CRAFT_SHARED_FLAVOR          : optional extra key component, use to
#                                         force a global re-build for a release
#    MULLE_CRAFT_SHARED_KEY_DEFINES     : extra string to fold into the key,
#                                         for defines not on the built-in list
#    MULLE_CRAFT_SHARED_EVENTS_FILE     : where to log events (default: the
#                                         writable layer's ".events")
#
# Enabling it:
#    A bare `export MULLE_CRAFT_SHARED_DEPENDENCY_DIR=...` reaches mulle-craft
#    when you call mulle-craft directly, but NOT when you go through
#    mulle-sde (which builds its environment from the project definitions and
#    drops unknown shell variables). There, use either
#
#       mulle-sde -DMULLE_CRAFT_SHARED_DEPENDENCY_PATH=<a>:<b> craft
#
#    or persist it in the environment:
#
#       mulle-sde env set MULLE_CRAFT_SHARED_DEPENDENCY_PATH <a>:<b>
#
# Measuring the hit rate:
#    Every decision is appended to the event log as
#       HIT|MISS|BUSY|RO|SKIP;<name>;<key>[;<layer>]
#    so e.g. `grep -c '^HIT;' <events>` gives the number of builds that were
#    avoided and the optional last field tells which layer answered. A summary
#    is logged at the end of every craftorder run, but only in verbose mode
#    (-v): it counts the WHOLE event log, which is appended to by every run
#    forever, so it is a diagnostic and not a per run statistic.
#
# Cleaning:
#    Layers are deliberately NOT removed by "clean tidy" or "gravetidy".
#    "clean shared-dependency-store" removes the WRITABLE layer only; read-only
#    layers belong to someone else and are left alone. Remove them explicitly
#    with
#       MULLE_CRAFT_SHARED_REMOVE_ALL_LAYERS=YES mulle-craft clean shared-dependency-store
#    ... and a read-only layer only with MULLE_CRAFT_SHARED_REMOVE_FORCE=YES as
#    well.
#
#    Named nodes are forgotten instead of a whole layer with
#       MULLE_CRAFT_SHARED_REMOVE_NODES="foo:bar" mulle-craft clean shared-dependency-store
#    which is the manual override for the one thing the key can not know: the
#    revisions of a node's dependencies. Forget what is stale and the next
#    craft rebuilds it. Every layer is considered, because a node left behind
#    in a sturdier layer would answer the lookup again; a read-only layer
#    still needs ..._REMOVE_FORCE=YES.
#
#    The everyday form is the node's name alone: "mulle-craft clean <name>"
#    (and with it "mulle-sde clean <name>") forgets the node in the writable
#    layers, because the rebuild it asks for would otherwise be answered from
#    the cache again, which undoes the clean. It is tolerant - a node that is
#    not stored is not an error. The ..._REMOVE_NODES way above is the
#    insisting one, for a read-only layer or a name you want to hear about.
#
# NOTE: This is a prototype. The key does not (yet) fold in the revisions of
# transitive dependencies. Use MULLE_CRAFT_SHARED_FLAVOR per release, or
# "mulle-craft clean shared-dependency-store", when in doubt.
#
MULLE_CRAFT_STORE_SH='included'


craft::store::_r_configured_layers()
{
   if [ ! -z "${MULLE_CRAFT_SHARED_DEPENDENCY_PATH:-}" ]
   then
      if [ ! -z "${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}" ]
      then
         _log_warning "MULLE_CRAFT_SHARED_DEPENDENCY_PATH is set, \
ignoring MULLE_CRAFT_SHARED_DEPENDENCY_DIR \"${MULLE_CRAFT_SHARED_DEPENDENCY_DIR}\""
      fi

      RVAL="${MULLE_CRAFT_SHARED_DEPENDENCY_PATH}"
      return 0
   fi

   local dir

   dir="${MULLE_CRAFT_SHARED_DEPENDENCY_DIR:-}"

   [ -z "${dir}" ]     && return 1
   [ "${dir}" = 'NO' ] && return 1

   RVAL="${dir}"
   return 0
}


#
# returns 0 if the shared store should be consulted for this process
#
craft::store::is_enabled()
{
   craft::store::_r_configured_layers || return 1

   #
   # Multi-phase builds are fine now: each node is built and archived by us in
   # its own private staging directory, so there is nothing to diff and nothing
   # concurrent to observe. In a phased run the node is dealt with in the first
   # install phase ("Headers"), which is why the per run state file exists.
   #
   # (This used to bail out when PARALLEL_PHASE was set, which silently switched
   # the store off for every project whose nodes carry "no-singlephase" - that
   # is, for almost all of them.)
   #
   return 0
}


#
# In a multi-phase craft ("Headers Compile Link") a node is visited once per
# phase. mulle-craft hands us a file that lives for exactly one craft run
# (MULLE_CRAFT_STORE_STATE, set up by craft::build::handle_parallel), which we
# use to remember what happened to a node:
#
#    <name>;served         the store answered, the products are in place
#    <name>;staged;<base>  we own the claim, the products are being staged
#
# The following phases then skip the node instead of building it again.
#
craft::store::r_state_file()
{
   [ -z "${MULLE_CRAFT_STORE_STATE:-}" ] && return 1

   RVAL="${MULLE_CRAFT_STORE_STATE}"
   return 0
}


# RVAL is "<state>[;<base>]" or empty when nothing is known about the node.
#
craft::store::r_node_state()
{
   local name="$1"
   local statefile
   local line

   RVAL=""

   craft::store::r_state_file || return 1
   statefile="${RVAL}"

   [ -f "${statefile}" ] || return 1

   line="`awk -F';' -v n="${name}" '$1 == n { print; exit }' "${statefile}"`"
   [ -z "${line}" ] && return 1

   RVAL="${line#*;}"
   return 0
}


craft::store::mark_state()
{
   local name="$1"
   local state="$2"

   [ -z "${name}" ] && return 1

   craft::store::r_state_file || return 0

   #
   # short appends, the phases may run in parallel subshells
   #
   printf "%s;%s\n" "${name}" "${state}" >> "${RVAL}"
   return 0
}


#
# Returns the configured layers as a ':' separated list of absolute paths,
# the first layer first and the (only) writable layer last. Returns 1 when no
# layer is configured, empty entries and 'NO' are dropped. The separator is
# ':' and not a newline, because r_split can not split on a newline (read -a
# stops at the first line).
#
craft::store::r_layers()
{
   craft::store::_r_configured_layers || return 1

   local raw
   local entries
   local entry
   local line
   local all

   raw="${RVAL}"
   r_split "${raw}" ':'
   entries=( "${RVAL[@]}" )

   all=""
   for entry in "${entries[@]}"
   do
      # tolerate whitespace around the colons
      while [ "${entry# }" != "${entry}" ]
      do
         entry="${entry# }"
      done
      while [ "${entry% }" != "${entry}" ]
      do
         entry="${entry% }"
      done

      case "${entry}" in
         ''|'NO'|'no')
            continue
         ;;
      esac

      r_absolutepath "${entry}"
      printf -v all "%s%s:" "${all}" "${RVAL}"
   done

   [ -z "${all}" ] && return 1

   RVAL="${all%:}"
   return 0
}


#
# The one and only layer that is written to: the last one in the list.
#
craft::store::r_write_layer()
{
   local layers
   local layer
   local last

   craft::store::r_layers || return 1
   r_split "${RVAL}" ':'
   layers=( "${RVAL[@]}" )

   last=""
   for layer in "${layers[@]}"
   do
      last="${layer}"
   done

   [ -z "${last}" ] && return 1

   RVAL="${last}"
   return 0
}


#
# A layer can protect itself from writes with a ".read-only" file.
#
craft::store::layer::is_read_only()
{
   [ -f "${1}/.read-only" ]
}


#
# How a layer should be named in a message: without a trailing slash and with
# the home directory abbreviated to "~". RVAL is that string. A layered store
# is only decipherable when a message says which layer it picked from, and the
# common single layer ("~/.mulle/var/cache/sde/shared") stays short that way.
#
craft::store::r_layer_display()
{
   local layer="$1"

   while [ "${#layer}" -gt 1 ] && [ "${layer%/}" != "${layer}" ]
   do
      layer="${layer%/}"
   done

   case "${layer}" in
      "${HOME}/"*)
         layer="~/${layer#${HOME}/}"
      ;;
   esac

   RVAL="${layer}"
   return 0
}


#
# The entry path without its extension. The archive is "${base}.tgz", the
# recorded prefix "${base}.prefix" and the claim "${base}.lock".
#
craft::store::r_node_base()
{
   local layer="$1"
   local key="$2"

   r_filepath_concat "${layer}" "${key}"
}


#
# Find the node for key in any layer. The LAST layer that has it wins, so a node
# that the current run built always beats a stale base. (The layers are scanned
# front to back and the answer is overwritten, instead of scanning backwards:
# zsh arrays are 1 based and numeric indexing is not portable.)
#
# An entry that can not be used in this dependency directory is passed over, see
# craft::store::entry::is_usable. When nothing usable is left, the run misses and
# builds the node itself. RVAL4 then holds the libraries that were missing from
# the entries that were passed over, which the caller may report.
#
# RVAL is the node base path (without ".tgz"), RVAL2 the layer that holds it,
# RVAL3 its index in the list. Returns 1 if no usable entry exists.
#
craft::store::r_find_node()
{
   local key="$1"
   local dependencydir="$2"
   local layers
   local layer
   local nodedir
   local index
   local found
   local founddir
   local foundlayer
   local foundindex
   local missing
   local unusable

   RVAL4=""

   [ -z "${key}" ] && return 1

   craft::store::r_layers || return 1
   r_split "${RVAL}" ':'
   layers=( "${RVAL[@]}" )

   found='NO'
   founddir=""
   foundlayer=""
   foundindex=""
   unusable=""

   index=0
   for layer in "${layers[@]}"
   do
      craft::store::r_node_base "${layer}" "${key}"
      nodedir="${RVAL}"

      if [ -f "${nodedir}.tgz" ]
      then
         if craft::store::entry::is_usable "${nodedir}" "${dependencydir}"
         then
            found='YES'
            founddir="${nodedir}"
            foundlayer="${layer}"
            foundindex="${index}"
         else
            missing="${RVAL}"

            _log_verbose "Not using \"${nodedir}.tgz\" from layer \"${layer}\", it needs \
${missing}, which this dependency directory does not provide"

            printf -v unusable "%s%s " "${unusable}" "${missing}"
         fi
      fi

      index=$(( index + 1 ))
   done

   if [ "${found}" = 'YES' ]
   then
      RVAL="${founddir}"
      RVAL2="${foundlayer}"
      RVAL3="${foundindex}"
      return 0
   fi

   RVAL="${key}"
   RVAL2=""
   RVAL3=""
   RVAL4="`printf '%s' "${unusable}" | tr ' ' '\n' | LC_ALL=C sort -u | tr '\n' ' '`"
   RVAL4="${RVAL4% }"
   return 1
}


#
# The defines that change what is compiled or linked. These have to be part of
# the key, otherwise a coverage/sanitizer run quietly reuses a plain entry
# (section 5 of the plan). Verified inputs:
#
#    --mulle-test                  -> OPTION_MULLE_TEST=YES
#    --preferred-library-style X   -> OPTION_PREFERRED_LIBRARY_STYLE
#    --ccache X                    -> OPTION_CCACHE
#    mulle-sde passes -DOTHER_CFLAGS+=--coverage etc. through to mulle-make,
#    which reads them from the environment.
#
# Anything not in this list can be added with MULLE_CRAFT_SHARED_KEY_DEFINES.
# Over-inclusion only costs hit rate, so the list is deliberately generous.
#
craft::store::r_key_defines()
{
   local name
   local value
   local result

   result=""

   for name in OPTION_MULLE_TEST \
               OPTION_PREFERRED_LIBRARY_STYLE \
               OPTION_CCACHE \
               MULLE_CRAFT_MAKE_OPTIONS \
               MULLE_CRAFT_MAKE_FLAGS \
               MULLE_MAKE_FLAGS \
               MULLE_CRAFT_SHARED_KEY_DEFINES \
               CC CFLAGS CPPFLAGS LDFLAGS \
               OTHER_CFLAGS OTHER_CPPFLAGS OTHER_LDFLAGS
   do
      eval "value=\"\${${name}:-}\""

      [ -z "${value}" ] && continue

      # canonical: no newlines, so the hash is stable
      value="`printf '%s' "${value}" | tr $'\n' ' '`"

      printf -v result "%s%s=%s;" "${result}" "${name}" "${value}"
   done

   RVAL="${result}"
   return 0
}


#
# Print the sourcetree configuration of a project: the local ("etc") and the
# shared ("share") scope, both in the order mulle-sourcetree reads them. That is
# where a project declares its dependencies. The file holds ${VARIABLE}
# placeholders, which are deliberately not expanded.
#
craft::store::r_project_config()
{
   local project="$1"

   local configname
   local file
   local result
   local scope

   configname="${MULLE_SOURCETREE_CONFIG_NAME:-config}"
   configname="${configname%%:*}"
   [ -z "${configname}" ] && configname="config"

   result=""

   for scope in etc share
   do
      file="${project}/.mulle/${scope}/sourcetree/config"
      if [ -f "${file}" ]
      then
         result="${result}$( cat "${file}" )"$'\n'
      fi

      [ "${configname}" = 'config' ] && continue

      file="${project}/.mulle/${scope}/sourcetree/${configname}"
      if [ -f "${file}" ]
      then
         result="${result}$( cat "${file}" )"$'\n'
      fi
   done

   RVAL="${result}"
   return 0
}


#
# The resolution decisions of a craftorder: "<name>=<provider>" for every name
# that is not a node of its own in this graph but a constituent ("shadow") of
# an amalgamation that is.
#
# mulle-sourcetree removes such a node from the craftorder (see
# sourcetree::craftorder::r_remove_amalgamated), so everything that declares the
# name is built and linked against the amalgamation instead. That is why the
# store key of a node has to know them, see craft::store::r_node_key.
#
# A declared dependency only shadows when its marks say "no-share-shirk", which
# is how the amalgamations mark their constituents. RVAL is a sorted, ";"
# terminated string, empty when nothing is shadowed. RVAL2 holds the nodes of
# the craftorder themselves (":" separated), which is what the ".needed" check
# asks when it wants to know whether a library will be there later.
#
craft::store::r_craftorder_providers()
{
   local craftorder="$1"

   local config
   local declaration
   local line
   local marks
   local name
   local nodes
   local project
   local provider
   local provides
   local result
   local rest

   result=""
   nodes=""

   [ -z "${craftorder}" ] && { RVAL=""; RVAL2=""; return 0; }

   while IFS= read -r line || [ ! -z "${line}" ]
   do
      project="${line%%;*}"

      [ -z "${project}" ] && continue

      r_expanded_string "${project}"
      project="${RVAL}"

      r_basename "${project}"
      provider="${RVAL}"

      r_colon_concat "${nodes}" "${provider}"
      nodes="${RVAL}"

      craft::store::r_project_config "${project}"
      config="${RVAL}"

      [ -z "${config}" ] && continue

      while IFS= read -r declaration || [ ! -z "${declaration}" ]
      do
         name="${declaration%%;*}"

         [ -z "${name}" ] && continue
         case "${name}" in
            '#'*)
               continue
            ;;
         esac

         # field 3 of "name;nodetype;marks;uuid;url;branch;tag;?;userinfo"
         rest="${declaration#*;}"
         rest="${rest#*;}"
         marks="${rest%%;*}"

         case ",${marks}," in
            *,no-share-shirk,*)
            ;;

            *)
               continue
            ;;
         esac

         # a constituent is named like the node it shadows
         r_basename "${name}"
         provides="${RVAL}"

         printf -v result "%s%s=%s;" "${result}" "${provides}" "${provider}"
      done <<< "${config}"
   done <<< "${craftorder}"

   # "a=b;c=d;" -> sorted, deduplicated, no trailing separator
   result="$( printf '%s' "${result}" | tr ';' $'\n' | LC_ALL=C sort -u | tr $'\n' ';' )"

   RVAL="${result%;}"

   # the nodes themselves, so that a requirement can be matched to a provider
   RVAL2="$( printf '%s' "${nodes}" | tr ':' $'\n' | LC_ALL=C sort -u | tr $'\n' ':' )"
   RVAL2="${RVAL2%:}"
   return 0
}


#
# Derive a filesystem friendly key from what can influence the produced
# artifacts. Returns 1 (RVAL holds the reason) when the node must not be
# shared. Namely: subprojects (no-memo) and checkouts that are not a git
# checkout at a revision. A checkout with local modifications is not refused,
# its working tree contents are part of the key instead (see below).
#
# Leaves MULLE_CRAFT_STORE_WORKTREE = YES when the checkout had local
# modifications, so that the caller can say so when it publishes.
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

   #
   # A symlink is fine. mulle workspaces symlink the sibling repositories in as
   # dependencies (MULLE_FETCH_SEARCH_PATH), and refusing those makes the store
   # useless exactly where it is worth most. What matters is not the symlink but
   # that the content is pinned - and a checkout with local modifications is not
   # unpinned, it is pinned to something that is not a revision. That state used
   # to be refused, which made the store useless for a workspace whose sibling
   # is being worked on (every project of mulle-gfx built the same mulle-core
   # over and over). It is folded into the key instead: same revision *and* the
   # same working tree give the same key and are shared, a different edit set
   # gives a different key. An edited parent is therefore never answered from
   # the cache, which is what makes this safe.
   #
   MULLE_CRAFT_STORE_WORKTREE=''

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

   local worktree

   worktree=''

   if [ ! -z "${dirty}" ]
   then
      #
      # The *contents* of the modifications, not just their names: two edits of
      # the same file have to give two keys, otherwise the artifact of the first
      # would answer for the second. `git diff HEAD` covers staged and unstaged
      # changes to tracked files, deletions included. Newly added untracked
      # files are covered by their name only (they are in `${dirty}` above),
      # not by their contents - the one gap left here.
      #
      worktree="`{ printf '%s\n' "${dirty}"; git -C "${project}" diff HEAD 2> /dev/null; } | \
                  sha1sum | cut -c1-8`"

      MULLE_CRAFT_STORE_WORKTREE='YES'
   fi

   # name is already sanitized by craft::path::r_name_from_evaledproject
   local sname

   r_basename "${name}"
   sname="${RVAL}"

   local defines

   craft::store::r_key_defines
   defines="${RVAL}"

   #
   # The hash covers everything that changes the produced bytes but is not in
   # the readable path: the source revision, the working tree contents (when
   # there are local modifications, see above), the non-standard build settings
   # (marks, style, toolchain, flavor and the defines/CFLAGS) and the resolution
   # decisions of the craftorder this node is built in (a declared dependency
   # can be a library of its own or a constituent of an amalgamation, see
   # craft::store::r_craftorder_providers). Sorted, then sha1 and the first 8
   # hex chars, so it is stable regardless of input order.
   #
   # A clean checkout adds nothing and a graph without amalgamations adds
   # nothing, so for those nothing changes because of this.
   #
   local input

   input="$( { printf '%s\n' "${rev}"; \
               printf '%s\n' "${marks}"; \
               printf '%s\n' "${style}"; \
               printf '%s\n' "${toolchain}"; \
               printf '%s\n' "${MULLE_CRAFT_SHARED_FLAVOR:-}"; \
               printf '%s\n' "${defines}"; \
               [ -z "${MULLE_CRAFT_STORE_PROVIDERS:-}" ] || \
                  printf 'providers=%s\n' "${MULLE_CRAFT_STORE_PROVIDERS}"; \
               [ "${MULLE_CRAFT_STORE_WORKTREE}" != 'YES' ] || \
                  printf 'worktree=%s\n' "${worktree}"; } | LC_ALL=C sort )"

   local hash

   hash="`printf '%s' "${input}" | sha1sum | cut -c1-8`"

   RVAL="${sname}/${sdk}-${platform}-${configuration}-${hash}"
   return 0
}


craft::store::_protect()
{
   exekutor chmod a-w "$1" || return 1
}


#
# Move every entry of `fromdir` into the existing `todir`: directories are
# created, files and symlinks are *renamed* over their old versions. A rename is
# atomic, so a concurrent reader sees either the complete old or the complete
# new file, never a half-written one.
#
# A plain `mv "${fromdir}" "${todir}"` can not be used: the dependency directory
# is a merge target shared by every node (include/, lib/), and a directory can
# not be renamed over a populated one.
#
craft::store::_move_tree_into()
{
   local fromdir="$1"
   local todir="$2"

   [ -d "${fromdir}" ] || return 0

   local dirs
   local entry
   local files

   #
   # Directories first, so that the renames below have a destination. Captured
   # and fed back with a here-document (not a pipe), so that a failure in the
   # body can return from the function.
   #
   dirs="`cd "${fromdir}" && find . -mindepth 1 -type d | sed -e 's|^\\./||'`"
   while IFS= read -r entry
   do
      [ -z "${entry}" ] && continue

      mkdir_if_missing "${todir}/${entry}" || return 1
   done <<EOF
${dirs}
EOF

   files="`cd "${fromdir}" && find . -mindepth 1 \\( -type f -o -type l \\) | sed -e 's|^\\./||'`"
   while IFS= read -r entry
   do
      [ -z "${entry}" ] && continue

      mv -f "${fromdir}/${entry}" "${todir}/${entry}" || return 1
   done <<EOF
${files}
EOF

   return 0
}


#
# Copy a whole tree. tar (not a file list) so that modes, empty directories
# and symlinks survive, all of which a find based list would quietly drop. Only
# used as a fallback when a node could not be archived, so that a successful
# build is still made visible.
#
# Unpacked into a private directory inside the destination and then renamed in
# (see craft::store::_move_tree_into), never extracted over the destination
# directly: tar truncates each target file in place, and a dependent node that
# builds in the same phase reads the shared dependency directory - it would see
# a half-written header.
#
craft::store::_copy_tree()
{
   local fromdir="$1"
   local todir="$2"

   [ -z "${fromdir}" ] && return 1
   [ -z "${todir}" ]   && return 1
   [ -d "${fromdir}" ] || return 1

   mkdir_if_missing "${todir}" || return 1

   local incoming

   _r_make_tmp_in_dir "${todir}" ".store-incoming" "d" || return 1
   incoming="${RVAL}"

   if ! (
      cd "${fromdir}" &&
      "${TAR:-tar}" -cf - .
   ) | (
      cd "${incoming}" &&
      "${TAR:-tar}" -xf -
   )
   then
      rmdir_safer "${incoming}"
      return 1
   fi

   if ! craft::store::_move_tree_into "${incoming}" "${todir}"
   then
      rmdir_safer "${incoming}"
      return 1
   fi

   rmdir_safer "${incoming}"
   return 0
}


#
# Is there a file with this name somewhere below dir? A shared library records
# what it needs by soname (e.g. "libmulle-allocator.so.9"), and that soname is
# the name of a real file in the dependency directory that provides it.
#
craft::store::has_provider()
{
   local dir="$1"
   local library="$2"

   [ -z "${dir}" ]     && return 1
   [ -z "${library}" ] && return 1
   [ -d "${dir}" ]     || return 1

   local found

   found="`find "${dir}" -name "${library}" -print -quit 2> /dev/null`"
   [ -z "${found}" ] && return 1
   return 0
}


#
# The load time requirements of a shared object, one library name per line
# (RVAL). Read with whatever tool is at hand: readelf (ELF), objdump (ELF and
# PE) or otool (Mach-O). Returns 1 when none of them is available or the file
# can not be read, in which case the requirement is not recorded and the check
# below is simply not made for this entry.
#
craft::store::r_binary_requires()
{
   local file="$1"
   local output
   local tool

   RVAL=""

   [ -z "${file}" ] && return 1
   [ -f "${file}" ] || return 1

   tool="`command -v readelf 2> /dev/null`"
   if [ ! -z "${tool}" ]
   then
      output="`"${tool}" -d "${file}" 2> /dev/null | \
                 sed -n -e 's/.*(NEEDED).*\\[\(.*\)\\].*/\1/p'`"
      if [ ! -z "${output}" ]
      then
         RVAL="${output}"
         return 0
      fi
   fi

   tool="`command -v objdump 2> /dev/null`"
   if [ ! -z "${tool}" ]
   then
      # ELF: "  NEEDED               libfoo.so.1", PE: "\tDLL Name: libfoo.dll"
      output="`"${tool}" -p "${file}" 2> /dev/null | \
                 sed -n -e 's/^[[:space:]]*NEEDED[[:space:]]\\{1,\\}\(.*\)$/\1/p' \
                        -e 's/^[[:space:]]*DLL Name:[[:space:]]*\(.*\)$/\1/p'`"
      if [ ! -z "${output}" ]
      then
         RVAL="${output}"
         return 0
      fi
   fi

   tool="`command -v otool 2> /dev/null`"
   if [ ! -z "${tool}" ]
   then
      # Mach-O: the first line is the file itself, the rest is "name (compat)"
      output="`"${tool}" -L "${file}" 2> /dev/null | \
                 sed -e '1d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*(.*$//' -e '/^$/d'`"
      if [ ! -z "${output}" ]
      then
         RVAL="${output}"
         return 0
      fi
   fi

   return 1
}


#
# Which libraries outside the tree does this tree need at load time? RVAL is a
# sorted list of names, one per line, or empty when there is nothing to check.
#
# A requirement is only recorded when the dependency directory can satisfy it
# *here*: what matters is not that the object is faithful but that it is usable,
# and a library that lives outside the dependency directory (libc, libgcc) is
# always there. Recording only the internal ones keeps every later check a
# plain "does this file exist".
#
craft::store::_r_tree_requires()
{
   local dir="$1"
   local dependencydir="$2"

   local object
   local objects
   local requirement
   local requires
   local result

   RVAL=""

   [ -z "${dir}" ]           && return 1
   [ -z "${dependencydir}" ] && return 1
   [ -d "${dir}" ]           || return 1

   #
   # a static archive is self contained, only a shared object can carry a link
   # dependency that is resolved when it is loaded
   #
   objects="`cd "${dir}" && \
               find . -type f \
                  \\( -name '*.so' -o -name '*.so.*' -o -name '*.dylib' -o -name '*.dll' \\) \
                  | sed -e 's|^\\./||'`"

   [ -z "${objects}" ] && return 1

   result=""

   while IFS= read -r object
   do
      [ -z "${object}" ] && continue

      craft::store::r_binary_requires "${dir}/${object}" || continue

      requires="${RVAL}"
      while IFS= read -r requirement
      do
         [ -z "${requirement}" ] && continue

         craft::store::has_provider "${dependencydir}" "${requirement}" || continue

         printf -v result "%s%s\n" "${result}" "${requirement}"
      done <<EOF
${requires}
EOF
   done <<EOF
${objects}
EOF

   [ -z "${result}" ] && return 1

   RVAL="`printf '%s' "${result}" | LC_ALL=C sort -u`"
   return 0
}


#
# Would a node with this name provide the library? A library is named after the
# node that builds it ("MulleObjC" -> libMulleObjC.so, "mulle-testallocator" ->
# libmulle-testallocator.so.6), and a Mach-O install name can carry a path while
# a DLL has no "lib" prefix at all. So the name of the library is compared to
# the nodes of the craftorder as it is and with a stripped "lib" prefix.
#
# Returns 1 when the craftorder is unknown: then nothing is guessed.
#
craft::store::has_expected_provider()
{
   local library="$1"

   local node
   local nodes
   local provided
   local stripped

   [ -z "${library}" ] && return 1

   nodes="${MULLE_CRAFT_STORE_NODES:-}"
   [ -z "${nodes}" ] && return 1

   provided="${library##*/}"
   provided="${provided%%.*}"
   stripped="${provided#lib}"

   provided="`printf '%s' "${provided}" | tr '[:upper:]' '[:lower:]'`"
   stripped="`printf '%s' "${stripped}" | tr '[:upper:]' '[:lower:]'`"

   r_split "${nodes}" ':'
   for node in "${RVAL[@]}"
   do
      node="`printf '%s' "${node}" | tr '[:upper:]' '[:lower:]'`"

      case "${node}" in
         "${provided}"|"${stripped}")
            return 0
         ;;
      esac
   done

   return 1
}


#
# Can this entry be used here? Returns 1 (RVAL holds the libraries that are
# missing) when the entry records requirements that this build does not
# provide. Then the node is not served from this entry, it is built here
# instead and published into the writable layer, which then shadows the
# unusable one (the last layer wins).
#
# A requirement counts as provided when its library is in the dependency
# directory now, or when a node of the current craftorder will provide it (see
# craft::store::has_expected_provider). The latter matters: in a multi-phase
# craft the libraries are linked only after all the headers and compiles, so at
# lookup time the dependency directory can not have them yet, and a good entry
# must not be rebuilt for that.
#
# What is left is the revision of a dependency: a node whose source is
# unchanged still has to be rebuilt when the dependency it is linked against
# dropped the library it needs from the graph.
#
craft::store::entry::is_usable()
{
   local base="$1"
   local dependencydir="$2"

   local neededfile
   local missing
   local requirement

   RVAL=""

   [ -z "${base}" ] && return 1

   neededfile="${base}.needed"
   [ -f "${neededfile}" ] || return 0

   missing=""

   while IFS= read -r requirement
   do
      [ -z "${requirement}" ] && continue

      craft::store::has_provider "${dependencydir}" "${requirement}" && continue
      craft::store::has_expected_provider "${requirement}" && continue

      printf -v missing "%s%s " "${missing}" "${requirement}"
   done < "${neededfile}"

   [ -z "${missing}" ] && return 0

   RVAL="${missing% }"
   return 1
}


#
# The prefix the products in this entry were built with. Recorded at capture
# time, because it is what absolute paths inside the products (pkg-config and
# libtool metadata) point at and has to be replaced on unpacking.
#
craft::store::r_recorded_prefix()
{
   local base="$1"
   local prefixfile

   prefixfile="${base}.prefix"
   if [ ! -f "${prefixfile}" ]
   then
      RVAL=""
      return 0
   fi

   RVAL="`cat "${prefixfile}"`"
   return 0
}


#
# Does anything in the tree carry the absolute prefix? Only .pc (pkg-config)
# and .la (libtool) can: they record absolute paths in their contents. The
# archive itself is relative throughout (member names, symlinks) and CMake
# package configs derive their prefix from their own location, so most entries
# have nothing to fix and get no ".prefix" sidecar at all.
#
craft::store::_tree_has_prefix()
{
   local dir="$1"
   local prefix="$2"

   [ -z "${prefix}" ] && return 1
   [ ! -d "${dir}" ]  && return 1

   local files

   files="`cd "${dir}" && \
            find . -type f \\( -name '*.pc' -o -name '*.la' \\) \
               | sed -e 's|^\./||'`"

   [ -z "${files}" ] && return 1

   local file

   while IFS= read -r file
   do
      [ -z "${file}" ] && continue

      grep -q -F "${prefix}" "${dir}/${file}" && return 0
   done <<EOF
${files}
EOF

   return 1
}


#
# Replace an absolute prefix in the metadata files that can carry one. Only
# .pc (pkg-config) and .la (libtool) are touched: CMake package configs derive
# their prefix from their own location and are relocatable already.
#
craft::store::rewrite_prefix()
{
   local dir="$1"
   local oldprefix="$2"
   local newprefix="$3"

   [ -z "${oldprefix}" ]               && return 0
   [ "${oldprefix}" = "${newprefix}" ] && return 0
   [ ! -d "${dir}" ]                   && return 0

   local files
   local escaped_old
   local escaped_new

   escaped_old="`printf '%s' "${oldprefix}" | sed -e 's/[\\&|]/\\\\&/g'`"
   escaped_new="`printf '%s' "${newprefix}" | sed -e 's/[\\&|]/\\\\&/g'`"

   files="`cd "${dir}" && \
            find . -type f \\( -name '*.pc' -o -name '*.la' \\) \
               | sed -e 's|^\./||'`"

   [ -z "${files}" ] && return 0

   local file
   local tmpfile

   #
   # a here-document, not a pipe: a failure in the body must abort the whole
   # rewrite, which it can not do in a subshell
   #
   while IFS= read -r file
   do
      [ -z "${file}" ] && continue

      grep -q -F "${oldprefix}" "${dir}/${file}" || continue

      tmpfile="${dir}/${file}.store-reprefix"

      if ! sed -e "s|${escaped_old}|${escaped_new}|g" \
               "${dir}/${file}" > "${tmpfile}"
      then
         rm -f "${tmpfile}"
         return 1
      fi

      mv "${tmpfile}" "${dir}/${file}" || return 1

      log_verbose "Reprefixed \"${file}\""
   done <<EOF
${files}
EOF

   return 0
}


#
# Unpack a captured archive into the dependency directory and point its
# metadata at where it now lives. Used when a node has just been built (the
# archive we published ourselves) and on a hit (someone else's archive).
#
# Like craft::store::_copy_tree this unpacks into a private directory and
# renames the contents in, so that a dependent node building in the same phase
# never reads a half-written file.
#
craft::store::restore()
{
   log_entry "craft::store::restore" "$@"

   local dependencydir="$1"
   local base="$2"
   local archive

   archive="${base}.tgz"
   [ -f "${archive}" ] || return 0

   mkdir_if_missing "${dependencydir}" || return 1

   local prefix

   craft::store::r_recorded_prefix "${base}"
   prefix="${RVAL}"

   local incoming

   _r_make_tmp_in_dir "${dependencydir}" ".store-incoming" "d" || return 1
   incoming="${RVAL}"

   if ! exekutor "${TAR:-tar}" -xzf "${archive}" -C "${incoming}"
   then
      rmdir_safer "${incoming}"
      return 1
   fi

   if [ ! -z "${prefix}" ]
   then
      if ! craft::store::rewrite_prefix "${incoming}" "${prefix}" "${dependencydir}"
      then
         rmdir_safer "${incoming}"
         return 1
      fi
   fi

   if ! craft::store::_move_tree_into "${incoming}" "${dependencydir}"
   then
      rmdir_safer "${incoming}"
      return 1
   fi

   rmdir_safer "${incoming}"
   return 0
}


#
# A claim records who holds it, so that a later run can tell a lock that is
# still held from one that a build left behind when it died. Without that a
# single killed build would disable sharing for its entry forever: claim would
# find the directory, report BUSY and every workspace would build the node
# locally from then on.
#
# Recorded is "<host>;<pid>;<epoch>". The host, because a layer can live on a
# shared filesystem where a pid says nothing about a process on another
# machine. The time, because a lock without an owner can only be judged by its
# age.
#
craft::store::_write_lock_owner()
{
   local lockdir="$1"
   local owner

   owner="${MULLE_HOSTNAME:-`hostname`};${MULLE_EXECUTABLE_PID:-$$};`timestamp_now`"

   redirect_exekutor "${lockdir}/owner" printf "%s\n" "${owner}" || true
}


# RVAL is "<host>;<pid>;<epoch>" or empty when the lock has no owner file.
#
craft::store::r_lock_owner()
{
   local lockdir="$1"

   RVAL=""

   [ -f "${lockdir}/owner" ] || return 1

   IFS= read -r RVAL < "${lockdir}/owner" || RVAL=""
   [ ! -z "${RVAL}" ]
}


#
# Has the claim been left behind? A claim whose owner is provably gone (same
# host, pid not alive) is stale right away. Everything else - an owner on
# another host, an unreadable owner, a lock without an owner file at all - only
# after a generous age, because breaking a lock that is actually held would let
# two builds publish the same entry at once. A locked entry is a performance
# problem, a doubly published one is a correctness problem, so the bias is
# deliberate.
#
craft::store::is_lock_stale()
{
   local lockdir="$1"
   local owner
   local rest
   local host
   local pid
   local created
   local stale_seconds="${MULLE_CRAFT_STORE_LOCK_STALE_SECONDS:-1800}"

   case "${stale_seconds}" in
      ''|*[!0-9]*)
         stale_seconds='1800'
      ;;
   esac

   host=""
   pid=""
   created=""

   if craft::store::r_lock_owner "${lockdir}"
   then
      #
      # "<host>;<pid>;<epoch>" and nothing else. Anything that does not parse
      # must not be interpreted at all: reading a timestamp out of a malformed
      # owner would call a live claim stale and let two builds publish at once.
      #
      owner="${RVAL}"

      case "${owner}" in
         *';'*';'*)
            host="${owner%%;*}"
            rest="${owner#*;}"
            pid="${rest%%;*}"
            created="${rest#*;}"
         ;;
      esac

      case "${pid}"     in ''|*[!0-9]*) pid=""     ;; esac
      case "${created}" in ''|*';'*|*[!0-9]*) created="" ;; esac
      [ ! -z "${host}" ] || pid=""

      if [ ! -z "${pid}" ] && [ "${host}" = "${MULLE_HOSTNAME:-`hostname`}" ]
      then
         #
         # our own claim is not stale, it is the one this run is about to
         # resume. The state file usually keeps us from getting here.
         #
         [ "${pid}" != "${MULLE_EXECUTABLE_PID:-$$}" ] || return 1

         if ! kill -0 "${pid}" 2> /dev/null
         then
            return 0
         fi
      fi
   fi

   #
   # Only the age of the directory is left to go on: either the owner says
   # nothing usable (another host or a malformed file) or there is no owner at
   # all, which is what a lock created before owners were recorded looks like.
   #
   [ -z "${created}" ] && created="`modification_timestamp "${lockdir}"`"
   [ -z "${created}" ] && return 1

   [ $(( `timestamp_now` - created )) -ge "${stale_seconds}" ]
}


#
# Take the claim on <base> without waiting (see section 6: a node somebody else
# builds is built locally by us as well, but not published). Returns 0 when
# this run owns the claim, 1 when it is taken - the caller then reports BUSY.
# A claim that was left behind is broken first.
#
craft::store::claim()
{
   local base="$1"
   local lockdir

   lockdir="${base}.lock"
   mkdir_if_missing "${lockdir%/*}"

   if mkdir "${lockdir}" 2> /dev/null
   then
      craft::store::_write_lock_owner "${lockdir}"
      return 0
   fi

   craft::store::is_lock_stale "${lockdir}" || return 1

   #
   # Move the dead lock out of the way instead of removing it in place: only
   # the mv is atomic, and a concurrent run may be in the middle of releasing
   # the very lock we decided to break.
   #
   local graveyard

   graveyard="${lockdir}.stale.${MULLE_EXECUTABLE_PID:-$$}.`timestamp_now`"

   if ! mv "${lockdir}" "${graveyard}" 2> /dev/null
   then
      return 1
   fi

   if ! mkdir "${lockdir}" 2> /dev/null
   then
      rmdir_safer "${graveyard}"
      return 1
   fi

   craft::store::_write_lock_owner "${lockdir}"

   _log_warning "Broke a stale shared store claim on ${C_MAGENTA}${C_BOLD}${base##*/}${C_WARNING}. \
A build that held it did not finish."

   rmdir_safer "${graveyard}"

   return 0
}


#
# Release the claim. It contains the owner file, so a plain rmdir would not do.
# Deliberately tolerant: releasing is the last thing a build does and must not
# turn a successful build into a failure. A claim that stays behind because of
# this is broken by is_lock_stale on the next run.
#
craft::store::release()
{
   local base="$1"

   [ -z "${base}" ] && return 1

   rm -f "${base}.lock/owner" 2> /dev/null || true
   rmdir "${base}.lock" 2> /dev/null || true

   return 0
}


#
# Capture a node as a gzipped tar archive. `stagedir` is the private directory
# the node was built into, so the archive is exactly what the build produced.
# `base` is the entry path without the ".tgz" suffix.
#
# `prefix` is the prefix the products were built with, kept in the sidecar so a
# restore can fix absolute paths in their metadata (section 8.3).
#
# `dependencydir` is only used to find out which libraries of this run the
# products need at load time; that list goes into the ".needed" sidecar, so that
# a later run can refuse the entry when it would not be usable there (see
# craft::store::entry::is_usable). It is empty when the caller has no dependency
# directory, then no requirements are recorded.
#
craft::store::capture()
{
   log_entry "craft::store::capture" "$@"

   local stagedir="$1"
   local base="$2"
   local prefix="${3:-${stagedir}}"
   local dependencydir="${4:-}"

   [ -z "${base}" ]       && return 1
   [ ! -d "${stagedir}" ] && return 1

   mkdir_if_missing "${base%/*}" || return 1

   local tmpfile

   tmpfile="${base}.tgz.tmp"
   exekutor rm -f "${tmpfile}"

   if ! (
      cd "${stagedir}" &&
      "${TAR:-tar}" -czf "${tmpfile}" .
   )
   then
      exekutor rm -f "${tmpfile}"
      return 1
   fi

   craft::store::_protect "${tmpfile}" || return 1

   #
   # The sidecar is only needed when the products actually record the absolute
   # prefix (see _tree_has_prefix). Writing it for every entry would mean that
   # every restore scans its whole dependency directory for a string that is
   # not there. Write it first, then rename the archive into place: the archive
   # under its real name is the "complete" marker and a reader must never see
   # it without its prefix.
   #
   local prefixfile

   prefixfile="${base}.prefix"

   if craft::store::_tree_has_prefix "${stagedir}" "${prefix}"
   then
      redirect_exekutor "${prefixfile}" printf "%s\n" "${prefix}" || return 1
   else
      log_verbose "Products are relocatable, not recording a prefix"

      # an earlier capture may have left one behind
      remove_file_if_present "${prefixfile}"
   fi

   #
   # Likewise before the rename: the entry is complete (its archive exists)
   # only together with what a reader has to know about it.
   #
   local neededfile

   neededfile="${base}.needed"

   if craft::store::_r_tree_requires "${stagedir}" "${dependencydir}"
   then
      redirect_exekutor "${neededfile}" printf "%s\n" "${RVAL}" || return 1
   else
      log_verbose "Products need no library of this dependency directory"

      remove_file_if_present "${neededfile}"
   fi

   mv "${tmpfile}" "${base}.tgz" || return 1
   return 0
}


#
# Where do events go ? The writable layer, unless it is read-only, then
# MULLE_CRAFT_SHARED_EVENTS_FILE (if given) or only the log.
#
craft::store::r_events_file()
{
   local file

   craft::store::r_write_layer || return 1

   if ! craft::store::layer::is_read_only "${RVAL}"
   then
      RVAL="${RVAL}/.events"
      return 0
   fi

   file="${MULLE_CRAFT_SHARED_EVENTS_FILE:-}"
   [ -z "${file}" ] && return 1

   r_absolutepath "${file}"
   return 0
}


craft::store::log_event()
{
   local event="$1"
   local name="$2"
   local detail="${3:-}"
   local layer="${4:-}"

   local eventsfile

   if craft::store::r_events_file
   then
      eventsfile="${RVAL}"
      mkdir_if_missing "${eventsfile%/*}"
      redirect_append_exekutor "${eventsfile}" \
         printf "%s;%s;%s%s\n" \
            "${event}" "${name}" "${detail}" "${layer:+;${layer}}"
   fi

   log_verbose "Shared store: ${event} ${name}${detail:+ (${detail})}${layer:+ in layer ${layer}}"
}


#
# A diagnostic for -v: how the events in the layer have been decided so far.
# The event log is appended to by every craft run and every user of the layer,
# it is never truncated, so these are lifetime counts and not the numbers of
# the run that just finished. To measure a single run, note the line count of
# the events file before and after, or use MULLE_CRAFT_SHARED_EVENTS_FILE.
#
craft::store::print_summary()
{
   craft::store::is_enabled || return 0

   local eventsfile

   craft::store::r_events_file || return 0
   eventsfile="${RVAL}"

   [ -f "${eventsfile}" ] || return 0

   local counts
   local layers
   local perlayer

   counts="$(awk -F';' '{ count[$1]++ } \
                        END { printf "hits=%d misses=%d skipped=%d busy=%d readonly=%d", \
                                      count["HIT"], count["MISS"], count["SKIP"], count["BUSY"], count["RO"] }' \
            "${eventsfile}")"

   layers=0
   if craft::store::r_layers
   then
      r_split "${RVAL}" ':'
      layers="${#RVAL[@]}"
   fi

   perlayer="`awk -F';' '/^HIT;/ && NF > 4 { count[$5]++ } \
                        END { for( i in count) printf "%s=%d\n", i, count[i] }' \
             "${eventsfile}" | LC_ALL=C sort | tr '\n' ' '`"

   log_verbose "Shared store (all runs so far): ${counts} layers=${layers:-0} ${perlayer}(${eventsfile})"
}


#
#
# Forget specific nodes in every layer. This is the deliberate answer to the
# one thing the key can not know: its hash only covers a node's own revision,
# so a change in a dependency does not invalidate its dependents. Forget the
# nodes you know are stale and the next craft rebuilds them.
#
# Every layer is considered, not just the writable one, because the LAST layer
# that has a node wins: leaving the archive behind in a sturdier layer would
# keep answering the lookup and nothing would be rebuilt at all. A read-only
# layer is still borrowed, so it is left alone unless `force` is YES, and the
# caller is told that the invalidation did not take effect.
#
# Returns 1 when at least one read-only layer was skipped or nothing was
# forgotten at all, because then the next craft would not rebuild.
#
craft::store::remove_nodes()
{
   local option_force="$1"
   local option_dry_run="$2"
   local names="$3"

   local layers
   local list
   local names_list
   local clean_names
   local present
   local layer
   local name
   local removed
   local refused

   #
   # sanity: only a bare basename is used, so that "foo/Debug" or "../../etc"
   # can not escape a layer
   #
   r_split "${names}" ':'
   names_list=( "${RVAL[@]}" )

   clean_names=''
   for name in "${names_list[@]}"
   do
      [ -z "${name}" ] && continue

      r_basename "${name}"

      case "${RVAL}" in
         ''|'.'|'..')
            log_warning "Ignoring unusable node name \"${name}\""
            continue
         ;;
      esac

      printf -v clean_names "%s%s:" "${clean_names}" "${RVAL}"
   done

   if [ -z "${clean_names}" ]
   then
      log_warning "No usable node name to invalidate was given"
      return 1
   fi

   clean_names="${clean_names%:}"

   craft::store::r_layers || return 1

   layers="${RVAL}"
   r_split "${layers}" ':'
   list=( "${RVAL[@]}" )
   r_split "${clean_names}" ':'
   names_list=( "${RVAL[@]}" )

   removed=0
   refused=0

   for layer in "${list[@]}"
   do
      [ -z "${layer}" ] && continue

      #
      # Only a layer that actually holds one of the nodes is of interest: an
      # unrelated read-only layer must not refuse the invalidation.
      #
      present=''
      for name in "${names_list[@]}"
      do
         if [ -d "${layer}/${name}" ]
         then
            printf -v present "%s%s:" "${present}" "${name}"
         fi
      done

      [ -z "${present}" ] && continue

      if craft::store::layer::is_read_only "${layer}" && [ "${option_force}" != 'YES' ]
      then
         refused=$(( refused + 1 ))

         _log_warning "Refusing to invalidate in read-only shared dependency layer \"${layer}\". \
${C_INFO}It is only picked from and may belong to another project or release. \
Use --force (MULLE_CRAFT_SHARED_REMOVE_FORCE=YES) to forget nodes there as well."

         continue
      fi

      present="${present%:}"
      r_split "${present}" ':'
      for name in "${RVAL[@]}"
      do
         [ -z "${name}" ] && continue

         if [ "${option_dry_run}" = 'YES' ]
         then
            log_info "Would forget \"${name}\" in \"${layer}\""
            continue
         fi

         log_verbose "Forgetting \"${name}\" in \"${layer}\""

         chmod -R u+w "${layer}/${name}" 2> /dev/null || true
         rmdir_safer "${layer}/${name}"
         removed=$(( removed + 1 ))
      done
   done

   if [ "${option_dry_run}" = 'YES' ]
   then
      log_info "Dry run: nothing was forgotten"
      return 0
   fi

   if [ ${removed} -eq 0 ] || [ ${refused} -ne 0 ]
   then
      _log_warning "Invalidation did not take effect (forgotten=${removed}, read-only layers skipped=${refused}). \
${C_INFO}A node has to be gone from every layer, otherwise the last layer that has it answers again. \
Run 'mulle-sde shared invalidate' without arguments to see the stored node names, \
and 'mulle-craft clean shared-dependency-store' to drop a whole layer."
      return 1
   fi

   log_info "Forgot ${removed} shared dependency store node(s)"
   return 0
}


#
# The tolerant sibling of craft::store::remove_nodes, for a command that only
# *wants* a node rebuilt instead of insisting on it: "mulle-craft clean <name>"
# and with it "mulle-sde clean <name>". In a shared store the rebuild would be
# answered from the cache again, so the node has to be forgotten there as well,
# otherwise the clean is a no-op.
#
# Tolerant, because a node that is not stored at all is not a mistake - it just
# means that no cache is in the way. A node that only a read-only layer holds
# is still reported by remove_nodes, because there the rebuild really would be
# shadowed (forget it there with --force to change that).
#
craft::store::forget_node()
{
   local name="$1"

   craft::store::is_enabled || return 0

   #
   # only a bare basename, so that "foo/Debug" or "../../etc" can not escape a
   # layer
   #
   r_basename "${name}"
   name="${RVAL}"

   case "${name}" in
      ''|'.'|'..')
         return 0
      ;;
   esac

   craft::store::r_layers || return 0

   local layers
   local list
   local layer
   local present

   layers="${RVAL}"
   r_split "${layers}" ':'
   list=( "${RVAL[@]}" )

   present='NO'
   for layer in "${list[@]}"
   do
      [ -z "${layer}" ] && continue

      if [ -d "${layer}/${name}" ]
      then
         present='YES'
         break
      fi
   done

   if [ "${present}" = 'NO' ]
   then
      log_fluff "No \"${name}\" in the shared dependency store to forget"
      return 0
   fi

   log_verbose "Forgetting \"${name}\" in the shared dependency store, so the next craft does not answer with the cache"

   #
   # only the writable layers; a read-only layer that holds the node is reported
   # by remove_nodes, because there the invalidation really did not take effect
   #
   craft::store::remove_nodes 'NO' 'NO' "${name}"

   return 0
}


#
# Remove the writable layer. The other layers are not ours, they are only
# picked from, so they are left alone unless --all-layers is given. Named
# arguments are node names instead, which are forgotten in every layer (see
# craft::store::remove_nodes).
#
craft::store::remove()
{
   log_entry "craft::store::remove" "$@"

   local option_all='NO'
   local option_force='NO'
   local option_dry_run='NO'
   local names

   names=''

   while [ $# -ne 0 ]
   do
      case "$1" in
         '--all'|'--all-layers')
            option_all='YES'
         ;;

         '--force')
            option_force='YES'
         ;;

         '--dry-run')
            option_dry_run='YES'
         ;;

         -*)
            log_warning "Unknown option \"$1\" for craft::store::remove"
         ;;

         *)
            printf -v names "%s%s:" "${names}" "$1"
         ;;
      esac

      shift
   done

   if [ ! -z "${names}" ]
   then
      craft::store::remove_nodes "${option_force}" "${option_dry_run}" "${names%:}"
      return $?
   fi

   local layers
   local layer
   local any

   if [ "${option_all}" = 'YES' ]
   then
      craft::store::r_layers || return 0
   else
      craft::store::r_write_layer || return 0
   fi
   layers="${RVAL}"

   r_split "${layers}" ':'
   local list=( "${RVAL[@]}" )

   any='NO'
   for layer in "${list[@]}"
   do
      if [ ! -d "${layer}" ]
      then
         continue
      fi

      if craft::store::layer::is_read_only "${layer}"
      then
         if [ "${option_force}" = 'YES' ]
         then
            log_verbose "Cleaning read-only shared dependency layer \"${layer}\" (forced)"
         else
            _log_warning "Refusing to remove read-only shared dependency layer \"${layer}\". \
${C_INFO}It is only picked from and may belong to another project or release."
            continue
         fi
      else
         log_verbose "Cleaning shared dependency layer \"${layer}\""
      fi

      chmod -R u+w "${layer}" 2> /dev/null || true
      rmdir_safer "${layer}"
      any='YES'
   done

   [ "${any}" = 'NO' ] && log_verbose "No shared dependency layer was removed"

   return 0
}

:
