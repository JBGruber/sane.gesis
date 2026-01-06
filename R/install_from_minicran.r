#' Install Packages from a Local miniCRAN Repository
#'
#' Installs packages from a local miniCRAN repository located at a fixed path.
#'
#' @param pkgs Character vector of package names to install.
#' @param ... Additional arguments passed to \code{install.packages()}.
#'
#' @return NULL (called for side effects)
#'
#' @details
#' This is a convenience wrapper around \code{install.packages()} that uses
#' a predefined local miniCRAN repository path (\code{file:///S:/software/miniCRAN}).
#' For more flexible installation from zip archives, see \code{\link{install_minicran}}.
#'
#' @seealso \code{\link{install_minicran}} for installing from compressed repositories
#'
#' @examples
#' \dontrun{
#' install_from_minicran("dplyr")
#' install_from_minicran(c("ggplot2", "tidyr"))
#' }
#'
#' @export
install_from_minicran <- function(pkgs, ...) {
  install.packages(
    pkgs,
    repos = "file:///S:/software/miniCRAN",
    type = "win.binary",
    ...
  )
}

#' Install All Packages from a Compressed miniCRAN Repository
#'
#' Extracts and installs all packages from a compressed miniCRAN repository
#' (zip file) to the user's library directory.
#'
#' @param minicran Character string specifying the path to the compressed
#'   miniCRAN repository zip file. Default is \code{"S:/software/mincran_repo.zip"}.
#' @param verbose Logical indicating whether to display installation progress.
#'   Default is \code{TRUE}.
#'
#' @return Invisibly returns \code{NULL}.
#'
#' @details
#' This function performs the following steps:
#' \enumerate{
#'   \item Determines the user's R library location from \code{R_LIBS_USER}
#'   \item Extracts the R version from the library path
#'   \item Identifies package files matching the R version in the zip archive
#'   \item Extracts and installs each package to the user library
#'   \item Skips packages that are already installed
#' }
#'
#' The function expects the zip file to contain a standard miniCRAN structure
#' with packages in \code{bin/windows/contrib/R_VERSION/} directories.
#'
#' @note This function is designed for Windows binary packages. It uses a
#'   two-step unzipping process because packages themselves are zip files.
#'
#' @seealso \code{\link{build_minicran_repo}} for creating miniCRAN repositories
#' @seealso \code{\link{install_from_minicran}} for installing specific packages
#'
#' @examples
#' \dontrun{
#' # Install from default location
#' install_minicran()
#'
#' # Install from custom location
#' install_minicran("path/to/my_packages.zip")
#'
#' # Install silently
#' install_minicran(verbose = FALSE)
#' }
#'
#' @export
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
