## 4.3.0

* added experimental support for shared builds configuration



feature: add opt-in shared dependency store for rebuilt dependencies

* new opt-in shared dependency store caches built dependencies across projects via ``MULLE_CRAFT_SHARED_DEPENDENCY_DIR``
* dependency nodes are restored from the store on a hit and captured on a miss, skipping redundant builds
* ``MULLE_CRAFT_SHARED_DRY_RUN=YES`` reports store hits without restoring them
* new `mulle-craft clean shared-dependency-store` command; `clean dependency-store` now refuses to implicitly remove a nested shared store
* fixed: multiple `--allow-build-script` paths are now separated by colon instead of comma
* fixed: allow-build-script paths are resolved with `.foreachpath` so directories are handled correctly


## 4.2.0



feature: add opt-in shared dependency store for rebuilt dependencies

* new opt-in shared dependency store caches built dependencies across projects via ``MULLE_CRAFT_SHARED_DEPENDENCY_DIR``
* dependency nodes are restored from the store on a hit and captured on a miss, skipping redundant builds
* ``MULLE_CRAFT_SHARED_DRY_RUN=YES`` reports store hits without restoring them
* new `mulle-craft clean shared-dependency-store` command; `clean dependency-store` now refuses to implicitly remove a nested shared store
* fixed: multiple `--allow-build-script` paths are now separated by colon instead of comma
* fixed: allow-build-script paths are resolved with `.foreachpath` so directories are handled correctly


## 4.1.0


* support for no-actual-build (needed for "none" projects with a sourcetree)


### 4.0.1


* support for no-actual-build (needed for "none" projects with a sourcetree)
