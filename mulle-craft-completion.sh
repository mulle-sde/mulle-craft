_mulle_craft_complete()
{
   local cur prev words cword
   local commands="addiction-dir clean craftorder dependency-dir donefile find list log project qualifier quickstatus searchpath status style uname version kitchen-dir craftorder-kitchen-dir libexec-dir tool-env"
   local global_opts="-h --help -k --kitchen-dir -b --build-dir -d --definition-dir --aux-definition-dir -f --force -p --project-dir --no-craftorder-file --craftorder-file --craftorder-kitchen-dir --craftorder-build-dir --dependency-dir --test-environment --motd --no-motd --version --"
   local cur prev
   _get_comp_words_by_ref cur prev words cword

   if [ "$cword" -eq 1 ]; then
       case "$prev" in
           -d|--definition-dir|--aux-definition-dir|--craftorder-file)
               _filedir
               return
               ;;
           -k|--kitchen-dir|-p|--project-dir|--craftorder-kitchen-dir|--craftorder-build-dir|--dependency-dir)
               _filedir -d
               return
               ;;
           *)
               COMPREPLY=($(compgen -W "${global_opts} ${commands}" -- "$cur"))
               return
               ;;
       esac
   fi

   local cmd="${words[1]}"
   case "$cmd" in
       clean)
           local clean_opts="--touch"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${clean_opts} all craftorder dependency project" -- "$cur"))
           else
               local subcmd="${words[2]}"
               case "$subcmd" in
                   "")
                       COMPREPLY=()
                       ;;
                   *)
                       COMPREPLY=()
                       ;;
               esac
           fi
           ;;
       find)
           local find_opts="-h --help --project-dir --dependency-dir --item --no-platform --no-local"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${find_opts}" -- "$cur"))
           elif [ "$prev" == "--project-dir" -o "$prev" == "--dependency-dir" ]; then
               _filedir -d
           elif [ "$prev" == "--item" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       log)
           local log_opts="-h --help -c --configuration -e --executable -t --tool -p --platform -s --sdk --style"
           local log_cmds="list"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${log_opts} ${log_cmds}" -- "$cur"))
           elif [ "$prev" == "-c" -o "$prev" == "--configuration" ]; then
               COMPREPLY=()
           elif [ "$prev" == "-e" -o "$prev" == "--executable" ]; then
               _filedir
           elif [ "$prev" == "-t" -o "$prev" == "--tool" ]; then
               COMPREPLY=()
           elif [ "$prev" == "-p" -o "$prev" == "--platform" ]; then
               COMPREPLY=()
           elif [ "$prev" == "-s" -o "$prev" == "--sdk" ]; then
               COMPREPLY=()
           elif [ "$prev" == "--style" ]; then
               local styles="none auto relax strict tight i-auto i-relax i-strict i-tight"
               COMPREPLY=($(compgen -W "${styles}" -- "$cur"))
           else
               COMPREPLY=()
           fi
           ;;
       status)
           local status_opts="-h --help --output-no-color --output-terse -f --craftorder-file"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${status_opts}" -- "$cur"))
           elif [ "$prev" == "-f" -o "$prev" == "--craftorder-file" ]; then
               _filedir
           fi
           ;;
       style)
           local style_opts="-h --help --configuration --platform --sdk --style"
           local style_cmds="show list"
           local styles="none auto relax strict tight i-auto i-relax i-strict i-tight"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${style_opts} ${style_cmds}" -- "$cur"))
           elif [ "$prev" == "--style" ]; then
               COMPREPLY=($(compgen -W "${styles}" -- "$cur"))
           elif [ "$prev" == "--configuration" -o "$prev" == "--platform" -o "$prev" == "--sdk" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       project)
           local project_opts="-h --help --all --debug --lenient --mulle-test --no-hook --no-protect --release --serial --platform --sdk --style --target --"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${project_opts}" -- "$cur"))
           elif [ "$prev" == "--platform" -o "$prev" == "--sdk" -o "$prev" == "--style" -o "$prev" == "--target" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       craftorder)
           local craftorder_opts="-h --help --all --debug --lenient --mulle-test --no-hook --no-protect --release --serial --platform --sdk --style --target --"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${craftorder_opts}" -- "$cur"))
           elif [ "$prev" == "--platform" -o "$prev" == "--sdk" -o "$prev" == "--style" -o "$prev" == "--target" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       qualifier)
           local qualifier_opts="-h --help --configuration --debug --platform --release --sdk --version --no-lf --lf"
           local qualifier_cmds="print print-no-build match"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${qualifier_opts} ${qualifier_cmds}" -- "$cur"))
           elif [ "$prev" == "--platform" -o "$prev" == "--sdk" -o "$prev" == "--configuration" -o "$prev" == "--version" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       searchpath)
           local searchpath_opts="-h --help --if-exists --style --release --debug --test --configurations --kitchen --platforms --sdks"
           local searchpath_types="header library framework binary kitchen"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${searchpath_opts} ${searchpath_types}" -- "$cur"))
           elif [ "$prev" == "--style" ]; then
               local styles="none auto relax strict tight i-auto i-relax i-strict i-tight"
               COMPREPLY=($(compgen -W "${styles}" -- "$cur"))
           elif [ "$prev" == "--configurations" -o "$prev" == "--platforms" -o "$prev" == "--sdks" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       list)
           local list_opts="-h --help --all --debug --lenient --mulle-test --no-hook --no-protect --release --serial --platform --sdk --style --target --list-remaining --"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${list_opts}" -- "$cur"))
           elif [ "$prev" == "--platform" -o "$prev" == "--sdk" -o "$prev" == "--style" -o "$prev" == "--target" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       donefile)
           local donefile_opts="-h --help --configuration --platform --sdk --no-cat --no-local --no-shared"
           local donefile_cmds="cat list"
           if [ "$cword" -eq 2 ]; then
               COMPREPLY=($(compgen -W "${donefile_opts} ${donefile_cmds}" -- "$cur"))
           elif [ "$prev" == "--configuration" -o "$prev" == "--platform" -o "$prev" == "--sdk" ]; then
               COMPREPLY=()
           else
               COMPREPLY=()
           fi
           ;;
       quickstatus)
           COMPREPLY=()
           ;;
       "")
           COMPREPLY=($(compgen -W "${commands} ${global_opts}" -- "$cur"))
           ;;
       *)
           if [[ "$cur" == -* ]]; then
               COMPREPLY=($(compgen -W "${global_opts}" -- "$cur"))
           fi
           ;;
   esac
}

complete -F _mulle_craft_complete mulle-craft
