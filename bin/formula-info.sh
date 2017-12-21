# -- Formula Info --
# If you don't have this file, there will be no homebrew
# formula operations.
#
PROJECT="mulle-craft"      # your project/repository name
DESC="🚬 Build projects using cmake, configure or some other meta-build tools"
LANGUAGE="bash"             # c,cpp, objc, bash ...
# NAME="${PROJECT}"        # formula filename without .rb extension


DEPENDENCIES='${TOOLS_TAP}mulle-sourcetree
${TOOLS_TAP}mulle-make
cmake'

DEBIAN_DEPENDENCIES="mulle-sourcetree, mulle-make, cmake (>= 3.0.0), make"
