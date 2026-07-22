# MATCHPLAN-LOG.md — Timestamped Build Logs

## Problem

Build logs are hard to use for both humans and AI:

1. Logs are scattered across many numbered files (`00.cmake.log`,
   `01.cmake.log`, ...) in per-project `.log/` directories.
2. On rebuild, old logs are either silently overwritten or mixed with new ones.
   Dependency logs from a previous craft run appear alongside fresh project
   logs with no indication they're stale.
3. `mulle-sde log` dumps raw file paths and contents with no combined view.
4. There is no history — you can't see what the previous build said.


## Solution

Put each craft run's logs into a timestamped subdirectory under `.log/`:

```
kitchen/.craftorder/Debug/MulleObjC/.log/
   20260321T112305.0/       ← first run
      00.cmake.log
      01.cmake.log
      02.cmake.log
   20260321T113012.0/       ← second run
      00.cmake.log
      01.cmake.log
      02.cmake.log
```

The format is `YYYYMMDDTHHMMSS.N` where `.N` is a sequence number starting
at 0. If the directory already exists (two crafts in the same second), bump N.

By default, `mulle-sde log` shows only the latest timestamped subdirectory.
Old runs are preserved for comparison. A configurable cap prunes old runs.


## Files to Change

### 1. `mulle-craft/src/mulle-craft-build.sh` (write side)

#### New helper function: `craft::build::r_timestamped_logdir`

Add near the top of the file (after the existing helper functions, around
line 110). This function creates a new timestamped subdirectory.

```bash
craft::build::r_timestamped_logdir()
{
   local basedir="$1"    # e.g. kitchendir/.log

   mkdir_if_missing "${basedir}"

   local timestamp
   local seq
   local logdir

   timestamp="$(date '+%Y%m%dT%H%M%S')"
   seq=0

   while :
   do
      logdir="${basedir}/${timestamp}.${seq}"
      if [ ! -d "${logdir}" ]
      then
         break
      fi
      seq=$(( seq + 1 ))
   done

   RVAL="${logdir}"
}
```

No need to `mkdir` the result — mulle-make's plugins do `mkdir_if_missing`
on the logsdir they receive.


#### Change 1a: `craft::build::build_project` (line ~488–499)

This builds dependencies. Currently:

```bash
   # remove old logs
   local logdir

   r_filepath_concat "${kitchendir}" ".log"
   logdir="${RVAL}"

   case "${phase}" in
      'Singlephase'|'Headers'|'Header')
         rmdir_safer "${logdir}"
      ;;
   esac
```

Change to:

```bash
   local logdir

   r_filepath_concat "${kitchendir}" ".log"

   case "${phase}" in
      'Singlephase'|'Headers'|'Header')
         craft::build::r_timestamped_logdir "${RVAL}"
         logdir="${RVAL}"
      ;;

      *)
         # Compile/Link phases append to the same run's logdir.
         # Find the latest existing timestamped dir.
         logdir="$(ls -1d "${RVAL}"/[0-9]*.* 2>/dev/null | tail -1)"
         if [ -z "${logdir}" ]
         then
            craft::build::r_timestamped_logdir "${RVAL}"
            logdir="${RVAL}"
         fi
      ;;
   esac
```

**Why**: Headers/Singlephase starts a new run → new timestamp dir. Compile
and Link phases of the same run must append to the same dir. We find the
latest existing timestamped dir for that. If none exists (shouldn't happen
in normal flow), create one as fallback.


#### Change 1b: `craft::build::build_mainproject` (line ~2017–2024)

Currently:

```bash
   local logdir

   r_filepath_concat "${kitchendir}" ".log"
   logdir="${RVAL}"

   # remove old logs
   rmdir_safer "${logdir}"
```

Change to:

```bash
   local logdir

   r_filepath_concat "${kitchendir}" ".log"
   craft::build::r_timestamped_logdir "${RVAL}"
   logdir="${RVAL}"
```

**Why**: Main project always starts fresh. The old timestamped dirs remain
for history.


#### Change 1c: Add pruning (optional, in same function)

After creating the new timestamped logdir, prune old ones. Add a helper:

```bash
craft::build::prune_old_logdirs()
{
   local basedir="$1"
   local keep="${2:-4}"

   local dirs
   local count

   dirs="$(ls -1d "${basedir}"/[0-9]*.* 2>/dev/null)"
   count="$(wc -l <<< "${dirs}")"

   if [ ${count} -gt ${keep} ]
   then
      local remove_count=$(( count - keep ))

      head -${remove_count} <<< "${dirs}" | while IFS= read -r old
      do
         rmdir_safer "${old}"
      done
   fi
}
```

Call it right after `r_timestamped_logdir` in both places:

```bash
   craft::build::prune_old_logdirs "${basedir}" 4
```

The keep count (4) could later be made configurable via an environment
variable like `MULLE_CRAFT_LOG_KEEP`.


---

### 2. `mulle-craft/src/mulle-craft-log.sh` (read side)

#### New helper function: `craft::log::r_latest_logdir`

Add near the top (after `craft::log::usage`, around line 70):

```bash
#
# Given a .log base directory, find the latest timestamped subdirectory.
# Falls back to the basedir itself for backward compatibility with
# old-style logs that have *.log files directly in .log/.
#
craft::log::r_latest_logdir()
{
   local basedir="$1"

   local latest

   latest="$(ls -1d "${basedir}"/[0-9]*.* 2>/dev/null | tail -1)"
   if [ ! -z "${latest}" ]
   then
      RVAL="${latest}"
   else
      # backward compat: old-style logs directly in .log/
      RVAL="${basedir}"
   fi
}
```

**Why**: This is the central place that resolves "give me the latest run."
The fallback to basedir handles projects that haven't been rebuilt yet
(their `.log/` still has the old flat layout).


#### Change 2a: `craft::log::project_log_dirs` (line ~95)

Currently finds directories named `.log`:

```bash
   rexekutor find -H "${KITCHEN_DIR}" -type d -name .log
```

This still works — it finds the `.log` base dirs. The callers need to
resolve the latest timestamped subdir. See Change 2c.


#### Change 2b: `craft::log::list_tool_logs` (line ~130)

Currently iterates `*.log` files in the logdir:

```bash
   .foreachline i in `dir_list_files "${logdir}" "*.log" "f"`
```

This function receives `logdir` from its caller. Once the caller passes
the timestamped subdir (see 2c, 2d), this function works unchanged.

**No change needed here.**


#### Change 2c: `craft::log::list` (line ~179)

Currently passes `.log` dirs directly to `list_tool_logs`:

```bash
      .foreachline directory in ${directories}
      .do
         r_dirname "${directory#${KITCHEN_DIR}/}"
         configuration="${RVAL}"

         craft::log::list_tool_logs "${OPTION_OUTPUT}" "${directory}" "" "${configuration}"
      .done
```

Change to resolve the latest timestamped subdir:

```bash
      .foreachline directory in ${directories}
      .do
         r_dirname "${directory#${KITCHEN_DIR}/}"
         configuration="${RVAL}"

         craft::log::r_latest_logdir "${directory}"
         craft::log::list_tool_logs "${OPTION_OUTPUT}" "${RVAL}" "" "${configuration}"
      .done
```

Apply the same change to the craftorder loop below it (around line 245):

```bash
         craft::log::r_latest_logdir "${directory}"
         craft::log::list_tool_logs "${OPTION_OUTPUT}" "${RVAL}" "${name}" "${configuration}"
```


#### Change 2d: `craft::log::craftorders` (line ~330)

Currently globs directly in `.log/`:

```bash
   r_filepath_concat "${_kitchendir}" ".log" "*.${OPTION_TOOL:-*}.log"
   globpattern="${RVAL}"
```

Change to resolve the latest timestamped subdir first:

```bash
   local logbasedir

   r_filepath_concat "${_kitchendir}" ".log"
   logbasedir="${RVAL}"

   craft::log::r_latest_logdir "${logbasedir}"

   r_filepath_concat "${RVAL}" "*.${OPTION_TOOL:-*}.log"
   globpattern="${RVAL}"
```


#### Change 2e: `craft::log::project` (line ~406)

Currently:

```bash
   logfiles="`craft::log::directories_list_files "${directory}"/${configuration}/".log/" -- "*.${OPTION_TOOL:-*}.log" `"
```

Change to:

```bash
   local logbasedir

   logbasedir="${directory}/${configuration}/.log"
   craft::log::r_latest_logdir "${logbasedir}"

   logfiles="`craft::log::directories_list_files "${RVAL}/" -- "*.${OPTION_TOOL:-*}.log" `"
```


#### Change 2f: Add `--run` option to `craft::log::main` (line ~470)

Add a new option to select a specific run (not just the latest):

```bash
         -r|--run)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_RUN="$1"
         ;;
```

Then modify `craft::log::r_latest_logdir` to accept an optional run
selector:

```bash
craft::log::r_latest_logdir()
{
   local basedir="$1"
   local run="${OPTION_RUN}"

   local dirs

   dirs="$(ls -1d "${basedir}"/[0-9]*.* 2>/dev/null)"
   if [ -z "${dirs}" ]
   then
      # backward compat
      RVAL="${basedir}"
      return
   fi

   case "${run}" in
      ''|'latest')
         RVAL="$(tail -1 <<< "${dirs}")"
      ;;

      'all')
         # caller must handle multiple lines
         RVAL="${dirs}"
      ;;

      '-'[0-9]*)
         # relative: -1 = previous, -2 = two runs ago
         local offset="${run#-}"
         local count

         count="$(wc -l <<< "${dirs}")"
         local index=$(( count - 1 - offset ))

         if [ ${index} -lt 0 ]
         then
            index=0
         fi
         RVAL="$(sed -n "$(( index + 1 ))p" <<< "${dirs}")"
      ;;

      *)
         # exact timestamp prefix match
         RVAL="$(grep "/${run}" <<< "${dirs}" | tail -1)"
         if [ -z "${RVAL}" ]
         then
            fail "No log run matching \"${run}\""
         fi
      ;;
   esac
}
```

Usage examples:
- `mulle-sde log` — latest run (default)
- `mulle-sde log --run -1` — previous run
- `mulle-sde log --run all` — all runs
- `mulle-sde log --run 20260321T112305` — specific run


---

### 3. No changes needed

These files need **no modifications**:

- **`mulle-make/src/mulle-make-build.sh`** — receives `--log-dir` from
  mulle-craft and writes into it. The timestamped path is transparent.
- **`mulle-make/src/mulle-make-common.sh`** — `r_build_log_name` creates
  numbered files in whatever dir it's given. Works unchanged.
- **`mulle-make/src/plugins/*.sh`** — all plugins receive `logsdir` as
  parameter $9 and write into it. No changes.
- **`mulle-sde/mulle-sde`** — just delegates `log` to `mulle-craft log`.
- **`mulle-craft/src/mulle-craft-clean.sh`** — `clean` removes the entire
  kitchen dir, which includes all `.log/` subdirs. Works unchanged.


---

## Testing

### Existing tests that need updating

The existing unit tests in `mulle-craft/test/` capture the `--log-dir`
argument that mulle-craft passes to mulle-make. After this change the value
will include a timestamp subdirectory, so two things need to change:

#### 1. Normalize timestamps in `expect_content`

In `test/01-passthru-build/run-test` and `test/02-sourcetree-build/run-test`,
add a sed normalization step inside `expect_content` (or as a filter applied
to the output file before diffing) that replaces the timestamp portion:

```bash
# Normalize timestamped log dirs: .log/20260321T112305.0 → .log/<timestamp>
normalize_log_timestamps()
{
   sed 's|\.log/[0-9]\{8\}T[0-9]\{6\}\.[0-9]*|.log/<timestamp>|g'
}
```

Apply it when writing the output file and when reading the expected file:

```bash
# In expect_content, before the diff:
normalize_log_timestamps < "${output}" > "${output}.normalized"
normalize_log_timestamps < "${expect}" > "${expect}.normalized"
diffs="`diff -b "${output}.normalized" "${expect}.normalized"`"
rm -f "${output}.normalized" "${expect}.normalized"
```

#### 2. Update expected `.txt` files

Update the `--log-dir` lines in these 5 files to use `<timestamp>`:

- `test/01-passthru-build/mulle-make.txt`
- `test/01-passthru-build/mulle-make2.txt`
- `test/02-sourcetree-build/mulle-make.txt`
- `test/02-sourcetree-build/mulle-make2.txt`
- `test/02-sourcetree-build/mulle-make3.txt`

Example change in `mulle-make.txt`:

```
# Before:
--log-dir ${MULLE_TMP_DIR}/build/Debug/.log

# After:
--log-dir ${MULLE_TMP_DIR}/build/Debug/.log/<timestamp>
```

### New test: `06-log-timestamps`

Create `test/06-log-timestamps/run-test` to verify the new behavior:

```bash
#! /bin/sh
[ "${TRACE}" = 'YES' ] && set -x && : "$0" "$@"

###   ###   ###   ###   ###   ###   ###   ###   ###   ###   ###   ###   ###
MULLE_BASHFUNCTIONS_LIBEXEC_DIR="`mulle-bashfunctions libexec-dir`" || exit 1
export MULLE_BASHFUNCTIONS_LIBEXEC_DIR
. "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-boot.sh" || exit 1
. "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-bashfunctions.sh" || exit 1
###   ###   ###   ###   ###   ###   ###   ###   ###   ###   ###   ###   ###


run_mulle_craft()
{
   exekutor "${MULLE_CRAFT}" ${MULLE_CRAFT_FLAGS} "$@"
}


main()
{
   MULLE_CRAFT_FLAGS="$@"
   _options_mini_main "$@" && set -x

   local directory

   r_make_tmp_directory || exit 1
   directory="${RVAL}"

   local builddir logbasedir

   builddir="${directory}/build"
   logbasedir="${builddir}/Debug/.log"

   #
   # Test 1: First craft creates a timestamped subdir
   #
   MULLE_TMP_DIR="${directory}" \
   MULLE_TEST_DIR="${PWD}" \
   MULLE_MAKE="${PWD}/../mock-mulle-make" \
   BUILD_DIR="${builddir}" \
      run_mulle_craft project --style auto --debug

   local dirs count

   dirs="$(ls -1d "${logbasedir}"/[0-9]*.* 2>/dev/null)"
   count="$(printf '%s\n' "${dirs}" | grep -c .)"

   [ "${count}" -eq 1 ] || fail "Test 1: expected 1 timestamped dir, got ${count}"
   log_verbose "----- #1 PASSED (timestamped dir created) -----"

   #
   # Test 2: Second craft creates a second timestamped subdir
   #
   sleep 1

   MULLE_TMP_DIR="${directory}" \
   MULLE_TEST_DIR="${PWD}" \
   MULLE_MAKE="${PWD}/../mock-mulle-make" \
   BUILD_DIR="${builddir}" \
      run_mulle_craft project --style auto --debug

   dirs="$(ls -1d "${logbasedir}"/[0-9]*.* 2>/dev/null)"
   count="$(printf '%s\n' "${dirs}" | grep -c .)"

   [ "${count}" -eq 2 ] || fail "Test 2: expected 2 timestamped dirs, got ${count}"
   log_verbose "----- #2 PASSED (second run creates new dir) -----"

   #
   # Test 3: Timestamp format is YYYYMMDDTHHMMSS.N
   #
   local latest

   latest="$(ls -1d "${logbasedir}"/[0-9]*.* 2>/dev/null | tail -1)"
   r_basename "${latest}"

   if ! printf '%s\n' "${RVAL}" | grep -qE '^[0-9]{8}T[0-9]{6}\.[0-9]+$'
   then
      fail "Test 3: unexpected timestamp format: ${RVAL}"
   fi
   log_verbose "----- #3 PASSED (timestamp format correct) -----"

   #
   # Test 4: Same-second collision gets sequence number bumped
   #
   local ts="${RVAL%.*}"   # strip .N suffix
   local collision_dir="${logbasedir}/${ts}.0"

   mkdir_if_missing "${collision_dir}"

   MULLE_TMP_DIR="${directory}" \
   MULLE_TEST_DIR="${PWD}" \
   MULLE_MAKE="${PWD}/../mock-mulle-make" \
   BUILD_DIR="${builddir}" \
      run_mulle_craft project --style auto --debug

   # The new dir should be .1 (since .0 already exists for this second)
   if [ ! -d "${logbasedir}/${ts}.1" ]
   then
      fail "Test 4: expected ${ts}.1 to be created for collision"
   fi
   log_verbose "----- #4 PASSED (collision gets .1 suffix) -----"

   log_info "----- ALL PASSED -----"
   rmdir_safer "${directory}"
}


init()
{
   MULLE_CRAFT="${MULLE_CRAFT:-${PWD}/../../mulle-craft}"
}


init "$@"
main "$@"
```

This test needs a `CMakeLists.txt` (copy from `01-passthru-build/`) so
mulle-craft has a project to build.

### Manual integration tests

These verify the full stack (mulle-craft + mulle-sde log) and are run by
hand against a real project like MulleObjCContainerFoundation:

```bash
# Test A: Basic timestamped log creation
cd <test-project>
mulle-sde clean
mulle-sde craft
find ~/.mulle/var/cache/sde/*/kitchen -path '*/.log/[0-9]*' -type d
# Should show timestamped dirs like .log/20260321T112305.0/

# Test B: Multiple runs, log shows only latest
mulle-sde craft          # run 1
sleep 1
mulle-sde craft          # run 2 (only main project rebuilt)
ls kitchen/Debug/.log/   # should show two timestamped dirs
mulle-sde log            # should show only run 2's logs

# Test C: Previous run accessible
mulle-sde log --run -1   # should show run 1's logs

# Test D: Phased dep stays in one dir
mulle-sde craft --all
ls kitchen/.craftorder/Debug/MulleObjC/.log/
# ONE timestamped dir with 9 files (3 phases × 3 steps)

# Test E: Backward compatibility
# Manually create old-style flat logs:
mkdir -p /tmp/test-kitchen/Debug/.log
touch /tmp/test-kitchen/Debug/.log/00.cmake.log
# r_latest_logdir should return the basedir, not fail

# Test F: Pruning
for i in 1 2 3 4 5 6; do mulle-sde craft; sleep 1; done
ls kitchen/Debug/.log/
# Should show at most 4 timestamped dirs (oldest pruned)
```


## Summary of Changes

| File | Function | What changes |
|------|----------|-------------|
| `mulle-craft-build.sh` | NEW `craft::build::r_timestamped_logdir` | Creates `YYYYMMDDTHHMMSS.N` dir |
| `mulle-craft-build.sh` | NEW `craft::build::prune_old_logdirs` | Removes old dirs, keeps last N |
| `mulle-craft-build.sh` | `craft::build::build_project` | Use timestamped logdir instead of flat `.log/` |
| `mulle-craft-build.sh` | `craft::build::build_mainproject` | Use timestamped logdir instead of flat `.log/` |
| `mulle-craft-log.sh` | NEW `craft::log::r_latest_logdir` | Resolves latest (or selected) timestamped subdir |
| `mulle-craft-log.sh` | `craft::log::list` | Resolve timestamped subdir before listing |
| `mulle-craft-log.sh` | `craft::log::craftorders` | Resolve timestamped subdir before globbing |
| `mulle-craft-log.sh` | `craft::log::project` | Resolve timestamped subdir before listing |
| `mulle-craft-log.sh` | `craft::log::main` | Add `--run` option |
