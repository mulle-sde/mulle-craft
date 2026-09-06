if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]
then
   return 2>/dev/null
fi


#
#  Simple per-directory caches. Rebuilt lazily and invalidated whenever the
#  working directory changes, so they stay fresh across projects.
#
__mulle_craft_cached_pwd=
__mulle_craft_cached_dependencies=

__mulle_craft_reset_caches()
{
   local pwd

   pwd="$(pwd -P 2>/dev/null)"
   if [ "${pwd}" != "${__mulle_craft_cached_pwd}" ]
   then
      __mulle_craft_cached_pwd="${pwd}"
      __mulle_craft_cached_dependencies=
   fi
}


#
#  Word providers. Each prints one candidate per line.
#
__mulle_craft_commands()
{
   printf '%s\n' \
      "addiction-dir" \
      "clean" \
      "craftorder" \
      "craftorder-kitchen-dir" \
      "dependency" \
      "donefile" \
      "donefiles" \
      "find" \
      "install" \
      "libexec-dir" \
      "list" \
      "log" \
      "project" \
      "qualifier" \
      "quickstatus" \
      "searchpath" \
      "status" \
      "style" \
      "tool-env" \
      "uname" \
      "version"
}

__mulle_craft_global_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "-k" "--kitchen-dir" "-b" "--build-dir" \
      "-d" "--definition-dir" "--aux-definition-dir" \
      "-f" "--force" \
      "-p" "--project-dir" \
      "--no-craftorder-file" "--craftorder-file" \
      "--craftorder-kitchen-dir" "--craftorder-build-dir" \
      "--dependency-dir" \
      "--test-environment" "--motd" "--no-motd" \
      "--platform" "--sdk" "--configuration" \
      "--version" "--" \
      "-n" "--dry-run" "-s" "--silent" "--silent-but-warn" \
      "-v" "--verbose" "--very-verbose" "--very-very-verbose" \
      "--log-debug" "--log-environment" "--log-settings" "--log-exekutor" "--log-execution" \
      "--trace" "--trace-full-pwd" "--trace-profile" "--trace-pwd" "--trace-immediately" \
      "--mulle-no-color" "--mulle-no-colors" "--mulle-no-errors" "--mulle-clear-flags"
}

__mulle_craft_build_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--all" "--rebuild" "--no-rebuild" \
      "-l" "--lenient" "--no-lenient" \
      "--mulle-test" "--syntax-check" \
      "--hook" "--no-hook" \
      "--protect" "--no-protect" \
      "--release" "--debug" \
      "--parallel" "--no-parallel" "--serial" \
      "--parallel-make" "--no-parallel-make" "--serial-make" \
      "--parallel-link" "--no-parallel-link" "--serial-link" \
      "--no-parallel-phase" "--serial-phase" \
      "--no-donefiles" \
      "--no-clean-tmp" \
      "--no-keep-dependency-state" \
      "--dependency" "--only-dependency" "--no-dependency" \
      "--allow-all-scripts" "--allow-script" "--allow-build-script" "--no-allow-script" \
      "--no-platform" "--no-platform-craftinfo" \
      "--no-local" "--no-local-craftinfo" \
      "--list-remaining" \
      "--single-dependency" \
      "--configuration" "--configurations" \
      "--platform" "--platforms" \
      "--sdk" "--sdks" \
      "--style" "--dispense-style" "--dependency-style" \
      "--target" "--targets" \
      "--version" "--post-project" "--preferred-library-style" "--library-style" \
      "--callback" "--ccache" "--phases" "--no-memo-makeflags" \
      "--"
}

__mulle_craft_clean_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--touch" "--no-memo-makeflags" \
      "--configuration" "--platform" "--sdk" "--style"
}

__mulle_craft_path_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--configuration" "--debug" "--if-exists" \
      "--platform" "--release" "--sdk" "--style"
}

__mulle_craft_dependency_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--style"
}

__mulle_craft_donefile_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--local" "--no-local" \
      "--shared" "--no-shared" \
      "--no-cat" \
      "--configuration" "--platform" "--sdk"
}

__mulle_craft_find_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "-d" "--project-dir" \
      "--dependency-dir" \
      "--item" \
      "--no-platform" "--no-platform-craftinfo" \
      "--no-local" "--no-local-craftinfo" \
      "--configuration" "--platform" "--sdk" "--style"
}

__mulle_craft_log_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--all" "--raw" \
      "-e" "--executable" \
      "-r" "--run" \
      "-c" "--configuration" \
      "-p" "--platform" \
      "-s" "--sdk" \
      "--style" \
      "-t" "--tool" \
      "--output-format" "--output-filename"
}

__mulle_craft_qualifier_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--release" "--debug" \
      "--lf" "--no-lf" \
      "--configuration" "--platform" "--sdk" "--version"
}

__mulle_craft_searchpath_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--release" "--debug" "--mulle-test" \
      "--configurations" "--configuration" \
      "--platform" "--platforms" \
      "--sdk" "--sdks" \
      "--if-exists" \
      "--no-addiction" "--only-addiction" \
      "--kitchen" "--add-kitchen-path" \
      "--prefix-only" \
      "--style"
}

__mulle_craft_status_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--output-no-color" "--output-terse" "--no-memo-makeflags"
}

__mulle_craft_style_options()
{
   printf '%s\n' \
      "-h" "--help" "help" \
      "--configuration" "--platform" "--sdk" "--style"
}

__mulle_craft_styles()
{
   printf '%s\n' \
      "none" "auto" "relax" "strict" "tight" \
      "i-auto" "i-relax" "i-strict" "i-tight"
}

__mulle_craft_configurations()
{
   printf '%s\n' "Debug" "Release"
}

__mulle_craft_platforms()
{
   {
      printf '%s\n' "${MULLE_UNAME:-}"
      printf '%s\n' "Default" "linux" "darwin" "freebsd" "openbsd" "netbsd" "windows" "mingw" "solaris"
   } | sed '/^[[:space:]]*$/d' | sort -u
}

__mulle_craft_sdks()
{
   printf '%s\n' "Default"
}

__mulle_craft_tools()
{
   printf '%s\n' "cat" "grep" "less" "diff" "tail" "head" "sed" "awk" "sort" "rg"
}

__mulle_craft_run_selectors()
{
   printf '%s\n' "latest" "all" "-1"
}

__mulle_craft_output_formats()
{
   printf '%s\n' "cmd" "filename"
}

__mulle_craft_phases()
{
   printf '%s\n' "Headers" "Compile" "Link"
}

__mulle_craft_clean_names()
{
   printf '%s\n' "all" "craftorder" "dependency" "dependency-store" "project"
}

__mulle_craft_dependency_subcommands()
{
   printf '%s\n' "update" "begin" "end" "fail" "dir" "quickstatus" "status"
}

__mulle_craft_donefile_subcommands()
{
   printf '%s\n' "cat" "echo" "list"
}

__mulle_craft_log_subcommands()
{
   printf '%s\n' "list" "runs" "errors" "warnings" "diff" "summary" "status"
}

__mulle_craft_qualifier_subcommands()
{
   printf '%s\n' "print" "print-no-build" "match"
}

__mulle_craft_style_subcommands()
{
   printf '%s\n' "show" "list"
}

__mulle_craft_searchpath_types()
{
   printf '%s\n' "framework" "header" "include" "library" "binary" "kitchen"
}


#
#  Dynamic content: dependency names from craftorder files and the
#  dependency/addiction directories. Cached per working directory.
#
__mulle_craft_dependencies()
{
   local candidates names

   if [ -n "${__mulle_craft_cached_dependencies}" ]
   then
      printf '%s\n' "${__mulle_craft_cached_dependencies}"
      return 0
   fi

   names=""

   if [ "${CRAFTORDER_FILE:-}" != "NONE" ] && [ -n "${CRAFTORDER_FILE:-}" ]
   then
      names="${names}
$(sed -n -E '/^[[:space:]]*#/d; s/;[^;]*$//; s#.*/##; p' "${CRAFTORDER_FILE}" 2>/dev/null)"
   fi

   if [ -n "${MULLE_VIRTUAL_ROOT:-}" ]
   then
      for candidates in \
            "${MULLE_VIRTUAL_ROOT}/etc/craftorder" \
            "${MULLE_VIRTUAL_ROOT}/dependency/etc/craftorder" \
            "${MULLE_VIRTUAL_ROOT}/addiction/etc/craftorder"
      do
         if [ -f "${candidates}" ]
         then
            names="${names}
$(sed -n -E '/^[[:space:]]*#/d; s/;[^;]*$//; s#.*/##; p' "${candidates}" 2>/dev/null)"
         fi
      done
   fi

   if [ -n "${DEPENDENCY_DIR:-}" ] && [ -d "${DEPENDENCY_DIR}" ]
   then
      names="${names}
$(cd "${DEPENDENCY_DIR}" 2>/dev/null && for d in */; do [ -e "${d}" ] && printf '%s\n' "${d%/}"; done)"
   fi

   if [ -n "${ADDICTION_DIR:-}" ] && [ -d "${ADDICTION_DIR}" ]
   then
      names="${names}
$(cd "${ADDICTION_DIR}" 2>/dev/null && for d in */; do [ -e "${d}" ] && printf '%s\n' "${d%/}"; done)"
   fi

   if [ -d "dependency" ]
   then
      names="${names}
$(cd "dependency" 2>/dev/null && for d in */; do [ -e "${d}" ] && printf '%s\n' "${d%/}"; done)"
   fi

   if [ -d "addiction" ]
   then
      names="${names}
$(cd "addiction" 2>/dev/null && for d in */; do [ -e "${d}" ] && printf '%s\n' "${d%/}"; done)"
   fi

   __mulle_craft_cached_dependencies="$(printf '%s\n' "${names}" | sed '/^[[:space:]]*$/d' | sort -u)"
   printf '%s\n' "${__mulle_craft_cached_dependencies}"
}


#
#  Completion primitives
#
__mulle_craft_compgen()
{
   mapfile -t COMPREPLY < <(compgen "$@")
}

__mulle_craft_complete_words()
{
   local combined=""
   local arg

   for arg in "$@"
   do
      [ -n "${arg}" ] || continue
      if declare -F "__mulle_craft_${arg}" >/dev/null 2>&1
      then
         combined="${combined}
$( "__mulle_craft_${arg}" )"
      else
         combined="${combined}
${arg}"
      fi
   done

   __mulle_craft_compgen -W "${combined}" -- "${cur}"
}

__mulle_craft_files()
{
   if declare -F _filedir >/dev/null 2>&1
   then
      _filedir
   else
      __mulle_craft_compgen -f -- "${cur}"
   fi
}

__mulle_craft_dirs()
{
   __mulle_craft_compgen -d -- "${cur}"
}

__mulle_craft_complete_arg()
{
   case "$1" in
      file)             __mulle_craft_files ;;
      dir)              __mulle_craft_dirs ;;
      style)            __mulle_craft_complete_words "styles" ;;
      platform)         __mulle_craft_complete_words "platforms" ;;
      sdk)              __mulle_craft_complete_words "sdks" ;;
      configuration)    __mulle_craft_complete_words "configurations" ;;
      tool)             __mulle_craft_complete_words "tools" ;;
      run)              __mulle_craft_complete_words "run_selectors" ;;
      output-format)    __mulle_craft_complete_words "output_formats" ;;
      phases)           __mulle_craft_complete_words "phases" ;;
      dependency)       __mulle_craft_complete_words "dependencies" ;;
      free|'')          ;;
   esac
}


#
#  Return the argument type of an option, or nothing if it is a flag.
#  $1 = context ("" for the global flag section, "build" for the common build
#  options, or a command name), $2 = option.
#
__mulle_craft_optarg()
{
   local context="$1"
   local option="$2"

   case "${context}:${option}" in
      ":"--craftorder-file)
         printf 'file\n'; return 0
      ;;
      ":"-k|":"--kitchen-dir|":"-b|":"--build-dir|":"-d|":"--definition-dir|":"--aux-definition-dir|":"-p|":"--project-dir|":"--craftorder-kitchen-dir|":"--craftorder-build-dir|":"--dependency-dir)
         printf 'dir\n'; return 0
      ;;
      ":"--platform)
         printf 'platform\n'; return 0
      ;;
      ":"--sdk)
         printf 'sdk\n'; return 0
      ;;
      ":"--configuration)
         printf 'configuration\n'; return 0
      ;;

      "build:"--configuration|"build:"--configurations|"clean:"--configuration|"donefile:"--configuration|"donefiles:"--configuration|"find:"--configuration|"qualifier:"--configuration|"searchpath:"--configuration|"searchpath:"--configurations|"style:"--configuration|"craftorder-kitchen-dir:"--configuration|"path:"--configuration|"dependency:"--configuration)
         printf 'configuration\n'; return 0
      ;;
      "build:"--platform|"build:"--platforms|"clean:"--platform|"donefile:"--platform|"donefiles:"--platform|"find:"--platform|"qualifier:"--platform|"searchpath:"--platform|"searchpath:"--platforms|"style:"--platform|"craftorder-kitchen-dir:"--platform|"path:"--platform|"dependency:"--platform)
         printf 'platform\n'; return 0
      ;;
      "build:"--sdk|"build:"--sdks|"clean:"--sdk|"donefile:"--sdk|"donefiles:"--sdk|"find:"--sdk|"qualifier:"--sdk|"searchpath:"--sdk|"searchpath:"--sdks|"style:"--sdk|"craftorder-kitchen-dir:"--sdk|"path:"--sdk|"dependency:"--sdk)
         printf 'sdk\n'; return 0
      ;;
      "build:"--style|"build:"--dispense-style|"build:"--dependency-style|"clean:"--style|"find:"--style|"qualifier:"--style|"searchpath:"--style|"style:"--style|"craftorder-kitchen-dir:"--style|"path:"--style|"dependency:"--style)
         printf 'style\n'; return 0
      ;;
      "build:"--preferred-library-style|"build:"--library-style)
         printf 'style\n'; return 0
      ;;
      "build:"--target|"build:"--targets)
         printf 'free\n'; return 0
      ;;
      "build:"--phases)
         printf 'phases\n'; return 0
      ;;
      "build:"--single-dependency)
         printf 'dependency\n'; return 0
      ;;
      "build:"--post-project)
         printf 'file\n'; return 0
      ;;
      "build:"--callback|"build:"--ccache|"build:"--version|"build:"--no-memo-makeflags|"clean:"--no-memo-makeflags)
         printf 'free\n'; return 0
      ;;

      "find:"-d|"find:"--project-dir)
         printf 'dir\n'; return 0
      ;;
      "find:"--dependency-dir)
         printf 'dir\n'; return 0
      ;;
      "find:"--item|"qualifier:"--version)
         printf 'free\n'; return 0
      ;;

      "log:"-c|"log:"--configuration)
         printf 'configuration\n'; return 0
      ;;
      "log:"-p|"log:"--platform)
         printf 'platform\n'; return 0
      ;;
      "log:"-s|"log:"--sdk)
         printf 'sdk\n'; return 0
      ;;
      "log:"--style)
         printf 'style\n'; return 0
      ;;
      "log:"-t|"log:"--tool)
         printf 'tool\n'; return 0
      ;;
      "log:"-e|"log:"--executable)
         printf 'file\n'; return 0
      ;;
      "log:"-r|"log:"--run)
         printf 'run\n'; return 0
      ;;
      "log:"--output-format)
         printf 'output-format\n'; return 0
      ;;

      "clean:"--touch)
         printf 'free\n'; return 0
      ;;
   esac

   return 1
}


#
#  Context helpers
#
__mulle_craft_locate_command()
{
   local i
   local type

   cmd=""
   for (( i = 1; i < cword; i++ ))
   do
      case "${words[i]}" in
         --)
            break
            ;;
         -*)
            if type="$(__mulle_craft_optarg "" "${words[i]}")" && [ -n "${type}" ]
            then
               (( i++ ))
            fi
            ;;
         *)
            cmd="${words[i]}"
            return
            ;;
      esac
   done
}

__mulle_craft_after_double_dash()
{
   local i

   for (( i = 1; i < cword; i++ ))
   do
      if [ "${words[i]}" = "--" ]
      then
         return 0
      fi
   done
   return 1
}

__mulle_craft_positional_count()
{
   local i="$1"
   local count=0
   local type

   for (( ; i < cword; i++ ))
   do
      case "${words[i]}" in
         --)
            break
            ;;
         -*)
            if type="$(__mulle_craft_optarg "${context}" "${words[i]}")" && [ -n "${type}" ]
            then
               (( i++ ))
            fi
            ;;
         *)
            (( count++ ))
            ;;
      esac
   done

   printf '%d\n' "${count}"
}

__mulle_craft_first_positional()
{
   local i="$1"
   local type

   for (( ; i < cword; i++ ))
   do
      case "${words[i]}" in
         --)
            break
            ;;
         -*)
            if type="$(__mulle_craft_optarg "${context}" "${words[i]}")" && [ -n "${type}" ]
            then
               (( i++ ))
            fi
            ;;
         *)
            printf '%s\n' "${words[i]}"
            return 0
            ;;
      esac
   done

   return 1
}

__mulle_craft_options_for()
{
   case "$1" in
      clean)                 __mulle_craft_clean_options ;;
      craftorder-kitchen-dir|path) __mulle_craft_path_options ;;
      dependency)            __mulle_craft_dependency_options ;;
      donefile|donefiles)    __mulle_craft_donefile_options ;;
      find)                  __mulle_craft_find_options ;;
      log)                   __mulle_craft_log_options ;;
      qualifier)             __mulle_craft_qualifier_options ;;
      searchpath)            __mulle_craft_searchpath_options ;;
      status)                __mulle_craft_status_options ;;
      style)                 __mulle_craft_style_options ;;
      build|project|craftorder|list) __mulle_craft_build_options ;;
      *)                     return 1 ;;
   esac
}


#
#  Positional completions, per command.
#
__mulle_craft_complete_clean()
{
   __mulle_craft_complete_words "clean_names" "dependencies"
}

__mulle_craft_complete_craftorder_kitchen_dir()
{
   __mulle_craft_complete_words "dependencies"
}

__mulle_craft_complete_dependency()
{
   __mulle_craft_complete_words "dependency_subcommands"
}

__mulle_craft_complete_donefile()
{
   __mulle_craft_complete_words "donefile_subcommands"
}

__mulle_craft_complete_find()
{
   __mulle_craft_complete_words "dependencies"
}

__mulle_craft_complete_log()
{
   local count
   local sub

   count="$(__mulle_craft_positional_count 2)"
   case "${count}" in
      0)
         __mulle_craft_complete_words "log_subcommands" "dependencies" '*'
      ;;
      1)
         if sub="$(__mulle_craft_first_positional 2)"
         then
            case "${sub}" in
               list|runs|errors|warnings|diff|summary|status)
                  return
                  ;;
            esac
            __mulle_craft_complete_words "tools"
         fi
      ;;
   esac
}

__mulle_craft_complete_searchpath()
{
   __mulle_craft_complete_words "searchpath_types"
}

__mulle_craft_complete_qualifier()
{
   __mulle_craft_complete_words "qualifier_subcommands"
}

__mulle_craft_complete_style()
{
   __mulle_craft_complete_words "style_subcommands"
}

__mulle_craft_complete_default()
{
   __mulle_craft_complete_words "dependencies"
}


#
#  Main completion entry point
#
_mulle_craft_complete()
{
   local cur prev words cword
   local cmd="" context type opts

   if declare -F _get_comp_words_by_ref >/dev/null 2>&1
   then
      _get_comp_words_by_ref cur prev words cword
   else
      words=("${COMP_WORDS[@]}")
      cword="${COMP_CWORD}"
      cur="${COMP_WORDS[COMP_CWORD]}"
      prev="${COMP_WORDS[COMP_CWORD-1]}"
   fi

   cword="${cword:-0}"
   [ "${cword}" -eq 0 ] && return
   [ -z "${cur+x}" ] && return

   __mulle_craft_reset_caches

   if [ "${cword}" -eq 1 ]
   then
      __mulle_craft_complete_words "commands" "global_options"
      return
   fi

   __mulle_craft_locate_command

   if [ -z "${cmd}" ]
   then
      if type="$(__mulle_craft_optarg "" "${prev}")" && [ -n "${type}" ]
      then
         __mulle_craft_complete_arg "${type}"
      else
         __mulle_craft_complete_words "commands" "global_options"
      fi
      return
   fi

   context="${cmd}"
   case "${context}" in
      donefiles)              context="donefile" ;;
      project|craftorder|list) context="build" ;;
   esac

   if __mulle_craft_after_double_dash
   then
      return
   fi

   if type="$(__mulle_craft_optarg "${context}" "${prev}")" && [ -n "${type}" ]
   then
      __mulle_craft_complete_arg "${type}"
      return
   fi

   if [ "${cur#-}" != "${cur}" ]
   then
      if opts="$(__mulle_craft_options_for "${context}")"
      then
         __mulle_craft_compgen -W "${opts}" -- "${cur}"
      fi
      return
   fi

   case "${context}" in
      clean)                __mulle_craft_complete_clean ;;
      craftorder-kitchen-dir) __mulle_craft_complete_craftorder_kitchen_dir ;;
      dependency)           __mulle_craft_complete_dependency ;;
      donefile)             __mulle_craft_complete_donefile ;;
      find)                 __mulle_craft_complete_find ;;
      log)                  __mulle_craft_complete_log ;;
      searchpath)           __mulle_craft_complete_searchpath ;;
      qualifier)            __mulle_craft_complete_qualifier ;;
      style)                __mulle_craft_complete_style ;;
      build)
         ;;
      addiction-dir|dependency-dir|kitchen-dir|libexec-dir|tool-env|uname|version|install|quickstatus|status)
         ;;
      *)                    __mulle_craft_complete_default ;;
   esac
}

complete -F _mulle_craft_complete mulle-craft