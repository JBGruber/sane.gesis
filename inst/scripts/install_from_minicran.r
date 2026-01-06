# Standalone script for installing from miniCRAN repositories
# This file can be sourced on machines without the sane.gesis package installed

install_from_minicran <- function(pkgs, ...) {
  install.packages(
    pkgs,
    repos = "file:///S:/software/miniCRAN",
    type = "win.binary",
    ...
  )
}

install_minicran <- function(
  minicran = "S:/software/mincran_repo.zip",
  verbose = TRUE
) {
  libloc <- Sys.getenv("R_LIBS_USER")
  if (!dir.exists(libloc)) {
    .libPaths(new = libloc)
  }
  r_version <- regmatches(libloc, regexpr("\\d+\\.\\d+$", libloc))
  contrib_path <- file.path("bin/windows/contrib", r_version)
  zip_contents <- unzip(minicran, list = TRUE)

  # Filter for package zip files in the correct R version folder
  pkg_pattern <- paste0("^", contrib_path, "/[^/]+\\.zip$")
  pkg_files <- zip_contents$Name[grepl(pkg_pattern, zip_contents$Name)]

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
      message(paste("\rInstalling package", i, "of", n_pkgs), appendLF = FALSE)
    }
    # unpack zip files to temporary location first
    unzip(minicran, files = pkg_files[i], exdir = temp_dir)
    pkg_zip_path <- file.path(temp_dir, pkg_files[i])
    # check which package is in the archive
    pkg <- unzip(pkg_zip_path, list = TRUE)[1, 1]
    # check if package exists already
    if (file.exists(file.path(libloc, pkg))) {
      next
    }
    # then unpack to lib location
    unzip(pkg_zip_path, exdir = libloc)
  }
}
