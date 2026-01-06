#' Build a miniCRAN Repository from Project Files
#'
#' Scans R scripts, Quarto files, and R Markdown files in a directory to detect
#' package dependencies, downloads all required packages and their dependencies,
#' and creates a compressed miniCRAN repository.
#'
#' @param path Character string specifying the directory to scan for R files.
#'   Default is current directory.
#' @param mirror Character string specifying the CRAN mirror to use.
#'   Default is \code{"https://cloud.r-project.org"}.
#' @param type Character string specifying the package type. Options include
#'   \code{"win.binary"}, \code{"mac.binary"}, or \code{"source"}.
#'   Default is \code{"win.binary"}.
#' @param r_version Character string specifying the R version for binary packages.
#'   Default is \code{"4.3"}.
#' @param out_file Character string specifying the output zip file name.
#'   Default is \code{"mincran_repo.zip"}.
#'
#' @return Invisibly returns the path to the created zip file.
#'
#' @details
#' This function performs the following steps:
#' \enumerate{
#'   \item Scans R scripts using \code{attachment::att_from_rscripts()}
#'   \item Scans Quarto files using \code{attachment::att_from_qmds()}
#'   \item Scans R Markdown files using \code{attachment::att_from_rmds()}
#'   \item Resolves all package dependencies using \code{miniCRAN::pkgDep()}
#'   \item Downloads packages to a temporary repository using \code{miniCRAN::makeRepo()}
#'   \item Compresses the repository into a zip file
#' }
#'
#' @examples
#' \dontrun{
#' # Create a miniCRAN repository for Windows binaries
#' build_minicran_repo(
#'   path = ".",
#'   type = "win.binary",
#'   r_version = "4.3",
#'   out_file = "my_packages.zip"
#' )
#'
#' # Create a source package repository
#' build_minicran_repo(
#'   path = "./R",
#'   type = "source",
#'   out_file = "source_packages.zip"
#' )
#' }
#'
#' @export
build_minicran_repo <- function(
  path,
  mirror = "https://cloud.r-project.org",
  type = "win.binary",
  r_version = "4.3",
  out_file = "mincran_repo.zip"
) {
  cli::cli_progress_step(
    msg = "Checking R scripts for packages",
    msg_done = "Checked R scripts for packages"
  )
  pkgs <- attachment::att_from_rscripts(path = path, recursive = TRUE)
  cli::cli_progress_step(
    msg = "Checking Quarto files for packages",
    msg_done = "Checked Quarto files for packages"
  )
  pkgs <- c(pkgs, attachment::att_from_qmds(path = path, recursive = TRUE))
  cli::cli_progress_step(
    msg = "Checking R Markdown files for packages",
    msg_done = "Checked R Markdown files for packages"
  )
  pkgs <- c(pkgs, attachment::att_from_rmds(path = path, recursive = TRUE))
  cli::cli_progress_step(
    msg = "Querying for package dependencies",
    msg_done = "Queried for package dependencies"
  )
  # miniCRAN::pkgDep does not resolve dependecies recursivly
  npkgs <- 0
  while (npkgs < length(pkgs)) {
    npkgs <- length(pkgs)
    # we do not need base packages
    pkgs <- setdiff(pkgs, miniCRAN::basePkgs())
    pkgs <- unique(c(
      pkgs,
      miniCRAN::pkgDep(pkgs, repos = c(CRAN = mirror))
    ))
  }

  cli::cli_progress_step(
    msg = "Downloading {npkgs} packages",
    msg_done = "Downloaded packages"
  )
  dir.create(pth <- file.path(tempdir(), "miniCRAN"))

  miniCRAN::makeRepo(
    pkgs,
    path = pth,
    repos = mirror,
    type = type,
    Rversion = r_version,
    quiet = TRUE
  )
  cli::cli_progress_step(
    msg = "Compressing packages",
    msg_done = "Compressed {npkgs} packages into {.path {out_file}}"
  )
  zip::zip(zipfile = basename(out_file), dir(pth, recursive = TRUE), root = pth)
  file.copy(file.path(pth, basename(out_file)), out_file, overwrite = TRUE)
  invisible(out_file)
}
