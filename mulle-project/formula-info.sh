# -- Formula Info --
# If you don't have this file, there will be no homebrew
# formula operations.
#
PROJECT="mulle-craft"      # your project/repository uuid
DESC="🚬 Build projects using mulle-make and mulle-sourcetre"
LANGUAGE="bash"                # c,cpp, objc, bash ...
# NAME="${PROJECT}"        # formula filename without .rb extension

DEPENDENCIES='${MULLE_SDE_TAP}mulle-sourcetree
${MULLE_SDE_TAP}mulle-make
${MULLE_SDE_TAP}mulle-dispense
'

DEBIAN_DEPENDENCIES="mulle-sourcetree, mulle-make, mulle-dispense"
