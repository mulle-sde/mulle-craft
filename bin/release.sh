#! /bin/sh

NAME="mulle-build"
ORIGIN=public
VERSION="`./mulle-build --version | head -1`"


TAP="${1:-software}"
[ $# -ne 0 ] && shift
BRANCH="${1:-release}"
[ $# -ne 0 ] && shift
TAG="${1:-${VERSION}}"
[ $# -ne 0 ] && shift

#
#
#

RBFILE="${NAME}.rb"
HOMEBREWTAP="../homebrew-${TAP}"


directory="`mulle-bootstrap library-path`"

[ ! -d "${directory}" ] && echo "failed to locate mulle-bootstrap library" >&2 && exit 1

. "${directory}/mulle-bootstrap-logging.sh"


git_must_be_clean()
{
   local name
   local clean

   name="${1:-${PWD}}"

   if [ ! -d .git ]
   then
      fail "\"${name}\" is not a git repository"
   fi

   clean=`git status -s --untracked-files=no`
   if [ "${clean}" != "" ]
   then
      fail "repository \"${name}\" is tainted"
   fi
}


[ ! -d "${HOMEBREWTAP}" ] && fail "failed to locate \"${HOMEBREWTAP}\""


git_must_be_clean || exit 1

devbranch="`git rev-parse --abbrev-ref HEAD`"

#
# make it a release
#
git checkout "${BRANCH}"  || exit 1
git rebase "${devbranch}" || exit 1

# if rebase fails, we shouldn't be hitting tag now
git tag "${TAG}"         || exit 1

git push "${ORIGIN}" "${BRANCH}"  --tags  || exit 1
git push github "${BRANCH}"  --tags       || exit 1

./bin/generate-brew-formula.sh "${VERSION}" "${TAP}" > "${HOMEBREWTAP}/${RBFILE}"
(
   cd "${HOMEBREWTAP}" ;
   git add "${RBFILE}" ;
   git commit -m "${TAG} ${BRANCH} of ${NAME}" "${RBFILE}" ;
   git push origin master
)  || exit 1

git checkout "${devbranch}"          || exit 1
git push "${ORIGIN}" "${devbranch}"  || exit 1
