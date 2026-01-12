#' Install All Packages from a Compressed Portable Repository
#'
#' Extracts and installs all packages from a compressed portable package repository
#' (zip file) to the user's library directory.
#'
#' @param portable_repo Character string specifying the path to the compressed
#'   portable package repository zip file. Default is \code{"S:/software/portable_repo.zip"}.
#' @param pkgs Character vector of packages to install (caution: the function does
#'   not check dependencies).
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
#' The function expects the zip file to contain a standard CRAN-style repository
#' structure with packages in \code{bin/windows/contrib/R_VERSION/} directories.
#'
#' @note This function is designed for Windows binary packages. It uses a
#'   two-step unzipping process because packages themselves are zip files.
#'
#' @seealso \code{\link{build_portable_repo}} for creating portable package repositories
#' @seealso \code{\link{install_portable_repo}} for installing specific packages
#'
#' @examples
#' \dontrun{
#' # Install from default location
#' install_portable_repo()
#'
#' # Install from custom location
#' install_portable_repo("path/to/my_packages.zip")
#'
#' # Install silently
#' install_portable_repo(verbose = FALSE)
#' }
#'
#' @export
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
