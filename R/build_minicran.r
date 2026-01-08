#' Build a miniCRAN Repository from Project Files
#'
#' Scans R scripts, Quarto files, and R Markdown files in a directory to detect
#' package dependencies, downloads all required packages and their dependencies,
#' and creates a compressed miniCRAN repository.
#'
#' @param path Character string specifying the directory to scan for R files.
#'   Default is current directory.
#' @param pkgs Packages to include in plan/download.
#' @param mirror Character string specifying the CRAN mirror to use.
#'   Default is \code{"https://cloud.r-project.org"}.
#' @param recursive Logical. Whether to search for packages in a path recursivly.
#' @param type Character string specifying the package type. Options include
#'   \code{"win.binary"}, \code{"mac.binary"}, or \code{"source"}.
#'   Default is \code{"win.binary"}.
#' @param r_version Character string specifying the R version for binary packages.
#'   Default is \code{"4.3"}.
#' @param out_file Character string specifying the output zip file name.
#'   Default is \code{"mincran_repo.zip"}.
#' @param verbose Logical. Whether to print status to the screen.
#'
#' @return `plan_local_repo` returns a list of packages; `build_local_repo` invisibly returns
#'   the path to the created zip file.
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
#' # Create a local repository for Windows binaries
#' pkgs <- plan_local_repo(path = ".")
#' build_local_repo(pkgs)
#' }
#'
#' @export
plan_local_repo <- function(
  path,
  pkgs = NULL,
  mirror = "https://cloud.r-project.org",
  recursive = TRUE,
  verbose = TRUE
) {
  if (missing(path) && !is.character(pkgs)) {
    cli::cli_abort(
      "You need to provide either a {.code path} with R/Rmd/Qmd files or a vector of packages in {.code pkgs}."
    )
  }
  if (!is.character(pkgs)) {
    pkgs <- character()
  }
  if (!missing(path)) {
    if (verbose) {
      cli::cli_progress_step(
        msg = "Checking R scripts for packages",
        msg_done = "Checked R scripts for packages [npkgs = {length(pkgs)}]"
      )
    }
    pkgs <- attachment::att_from_rscripts(path = path, recursive = recursive)
    if (verbose) {
      cli::cli_progress_step(
        msg = "Checking Quarto files for packages",
        msg_done = "Checked Quarto files for packages [npkgs = {length(pkgs)}]"
      )
    }
    pkgs <- c(
      pkgs,
      attachment::att_from_qmds(path = path, recursive = recursive)
    )
    if (verbose) {
      cli::cli_progress_step(
        msg = "Checking R Markdown files for packages",
        msg_done = "Checked R Markdown files for packages [npkgs = {length(pkgs)}]"
      )
    }
    pkgs <- c(
      pkgs,
      attachment::att_from_rmds(path = path, recursive = recursive)
    )
    cli::cli_process_done()
  }
  pkgs <- pkgs_deps(pkgs, mirror = mirror, verbose = verbose)
  return(pkgs)
}


#' @rdname plan_local_repo
#' @export
build_local_repo <- function(
  pkgs,
  mirror = "https://cloud.r-project.org",
  type = "win.binary",
  r_version = "4.3",
  out_file = "mincran_repo.zip",
  verbose = TRUE
) {
  if (verbose) {
    cli::cli_progress_step(
      msg = "Downloading {length(pkgs)} packages",
      msg_done = "Downloaded packages"
    )
  }
  dir.create(pth <- file.path(tempdir(), "miniCRAN"), showWarnings = FALSE)

  miniCRAN::makeRepo(
    pkgs,
    path = pth,
    repos = mirror,
    type = type,
    Rversion = r_version,
    quiet = TRUE
  )
  if (verbose) {
    cli::cli_progress_step(
      msg = "Compressing packages",
      msg_done = "Compressed {length(pkgs)} packages into {.path {out_file}}"
    )
  }
  zip::zip(zipfile = basename(out_file), dir(pth, recursive = TRUE), root = pth)
  file.copy(file.path(pth, basename(out_file)), out_file, overwrite = TRUE)
  invisible(out_file)
}


pkgs_deps <- function(pkgs, mirror, verbose = TRUE) {
  if (verbose) {
    cli::cli_progress_step(
      msg = "Querying for package dependencies",
      msg_done = "Queried for package dependencies [npkgs = {length(pkgs)}]"
    )
  }
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
  return(pkgs)
}
