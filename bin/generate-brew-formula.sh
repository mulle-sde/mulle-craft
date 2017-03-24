#! /bin/sh
#
# Generate a formula for mulle-c11
#
PROJECT=MulleBuild  # ruby requires camel-case
TARGET=mulle-build
DESC="Cross-platform builder using cmake and mulle-bootstrap"

#
# Should be possible to leave unchanged
#
HOMEPAGE="http://www.mulle-kybernetik.com/software/git/${TARGET}"


VERSION="$1"
[ $# -eq 0 ] || shift
TAP="${1:-software}"
[ $# -eq 0 ] || shift
ARCHIVEURL="${1:-http://www.mulle-kybernetik.com/software/git/${TARGET}/tarball/${VERSION}"
[ $# -eq 0 ] || shift

set -e
set -x

[ "$VERSION" = "" ] && exit 1
[ "$ARCHIVEURL" = "" ] && exit 1


TMPARCHIVE="/tmp/${TARGET}-${VERSION}-archive"

if [ ! -f "${TMPARCHIVE}" ]
then
   curl -L -o "${TMPARCHIVE}" "${ARCHIVEURL}"
   if [ $? -ne 0 ]
   then
      echo "Download failed" >&2
      exit 1
   fi
   if [ ! -f "${TMPARCHIVE}" ]
   then
      echo "Download did not download file" >&2
      exit 1
  fi
else
   echo "Using cached file ${TMPARCHIVE} instead of downloading again" >&2
fi

#
# anything less than 17 KB is wrong
#
size="`du -k "${TMPARCHIVE}" | awk '{ print $1}'`"
if [ $size -lt 17 ]
then
   echo "Archive truncated or missing" >&2
   cat "${TMPARCHIVE}" >&2
   rm "${TMPARCHIVE}"
   exit 1
fi

HASH="`shasum -p -a 256 "${TMPARCHIVE}" | awk '{ print $1 }'`"

cat <<EOF
class ${PROJECT} < Formula
  homepage "${HOMEPAGE}"
  desc "${DESC}"
  url "${ARCHIVEURL}"
  version "${VERSION}"
  sha256 "${HASH}"

  depends_on 'mulle-kybernetik/${TAP}/mulle-bootstrap'
  depends_on 'cmake'

  def install
     system "./install.sh", "#{prefix}"
  end

  test do
  end
end
# FORMULA ${TARGET}.rb
EOF
