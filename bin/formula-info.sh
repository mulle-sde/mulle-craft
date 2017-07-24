# -- Formula Info --
# If you don't have this file, there will be no homebrew
# formula operations.
#
PROJECT="mulle-build"      # your project/repository name
DESC="🔨 Build and install tool on top of cmake and mulle-bootstrap"
LANGUAGE="bash"             # c,cpp, objc, bash ...
# NAME="${PROJECT}"        # formula filename without .rb extension

#
# Specify needed homebrew packages by name as you would when saying
# `brew install`.
#
# Use the ${DEPENDENCY_TAP} prefix for non-official dependencies.
# DEPENDENCIES and BUILD_DEPENDENCIES will be evaled later!
# So keep them single quoted.
#
DEPENDENCIES='${BOOTSTRAP_TAP}mulle-bootstrap'

DEBIAN_DEPENDENCIES="mulle-bootstrap (>= 3.8.2), cmake (>= 3.0.0), make"
