#! /bin/sh
#
# (c) 2016, coded by Nat!, Mulle KybernetiK, Codeon GmbH
#

if [ "${MULLE_BOOTSTRAP_NO_COLOR}" != "YES" ]
then
   # Escape sequence and resets
   C_RESET="\033[0m"

   # Useable Foreground colours, for black/white white/black
   C_RED="\033[0;31m"     C_GREEN="\033[0;32m"
   C_BLUE="\033[0;34m"    C_MAGENTA="\033[0;35m"
   C_CYAN="\033[0;36m"

   C_BR_RED="\033[0;91m"
   C_BOLD="\033[1m"

   #
   # restore colors if stuff gets wonky
   #
   trap 'printf "${C_RESET}"' TERM EXIT
fi


fail()
{
   printf "${C_BR_RED}$*${C_RESET}\n" >&2
   exit 1
}

#
# https://github.com/hoelzro/useful-scripts/blob/master/decolorize.pl
#

prefix=${1:-"/usr/local"}
[ $# -eq 0 ] || shift
mode=${1:-755}
[ $# -eq 0 ] || shift
bin="${1:-${prefix}/bin}"
[ $# -eq 0 ] || shift


if [ "$prefix" = "" ] || [ "$bin" = "" ] || [ "$mode" = "" ]
then
   echo "usage: mulle-install [prefix] [mode] [binpath]" >&2
   exit 1
fi


[ -z "`which "mulle-bootstrap" 2> /dev/null`" ] && fail "mulle-bootstrap not installed (https://github.com/mulle-nat/mulle-bootstrap)"


if [ ! -d "${bin}" ]
then
   mkdir -p "${bin}" || fail "could not create ${bin}"
fi

install -m "${mode}" mulle-build "${bin}" || fail "failed install into ${bin}"
printf "install: ${C_MAGENTA}${C_BOLD}mulle-build${C_RESET}\n" >&2

for i in analyze clean git install status tag test xcodeproj update
do
   ln -sf mulle-build "${bin}/mulle-${i}" || fail "failed install into ${bin}"
   printf "install: ${C_MAGENTA}${C_BOLD}mulle-${i}${C_RESET}\n" >&2
done

