# Standalone script for installing from portable repositories
# This file can be sourced on machines without the sane.gesis package installed

install_portable_repo <- function(
  portable_repo = "S:/software/portable_repo.zip",
  pkgs = NULL,
  verbose = TRUE
) {
  libloc <- Sys.getenv("R_LIBS_USER")
  if (!dir.exists(libloc)) {
    .libPaths(new = libloc)
  }
  r_version <- regmatches(libloc, regexpr("\\d+\\.\\d+$", libloc))
  contrib_path <- file.path("bin/windows/contrib", r_version)
  zip_contents <- utils::unzip(portable_repo, list = TRUE)

  # Filter for package zip files in the correct R version folder
  pkg_pattern <- paste0("^", contrib_path, "/[^/]+\\.zip$")
  pkg_files <- zip_contents$Name[grepl(pkg_pattern, zip_contents$Name)]

  if (!is.null(pkgs)) {
    include_pattern <- paste0("/", pkgs, "_[0-9.]+\\.zip", collapse = "|")
    pkg_files <- pkg_files[grepl(include_pattern, pkg_files)]
    if (length(pkgs) != length(pkg_files)) {
      warning("not all packages are present in the repo")
    }
  }

  if (length(pkg_files) == 0) {
    warning(sprintf("No packages found in %s", contrib_path))
    return(invisible(NULL))
  }

  # packages are also zip files, so 2-step unzipping is necessary
  temp_dir <- tempfile()
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  n_pkgs <- length(pkg_files)
  for (i in seq_along(pkg_files)) {
    if (verbose) {
      # use only base function in this script so it can run on a fresh install
      message(paste("\rInstalling package", i, "of", n_pkgs), appendLF = FALSE)
    }
    # unpack zip files to temporary location first
    utils::unzip(portable_repo, files = pkg_files[i], exdir = temp_dir)
    pkg_zip_path <- file.path(temp_dir, pkg_files[i])
    # check which package is in the archive
    pkg <- utils::unzip(pkg_zip_path, list = TRUE)[1, 1]
    # check if package exists already
    if (file.exists(file.path(libloc, pkg))) {
      next
    }
    # then unpack to lib location
    utils::unzip(pkg_zip_path, exdir = libloc)
  }
}
