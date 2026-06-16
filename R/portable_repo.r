#' Build a Portable Package Repository from Project Files
#'
#' Scans R scripts, Quarto files, and R Markdown files in a directory to detect
#' package dependencies, downloads all required packages and their dependencies,
#' and creates a compressed portable package repository.
#'
#' @param path Character string specifying the directory to scan for R files.
#'   Default is current directory.
#' @param pkgs Packages to download.
#' @param add_pkgs Additional packages to include.
#' @param recursive Logical. Whether to search for packages in a path recursivly.
#' @param platforms Character string specifying the package platforms. See
#'   [pkgdepends::current_r_platform] for options.
#' @param r_version Character string specifying the R version for binary packages.
#'   Default is \code{"4.3"}.
#' @param out_file Character string specifying the output zip file name.
#'   Default is \code{"portable_repo.zip"}.
#' @param write_requirements should the function write package dependencies into
#'   a txt file? Possible ansers: `TRUE`/`FALSE`/`"ask"`-`
#' @param verbose Logical. Whether to print status to the screen.
#'
#' @return `plan_portable_repo` returns a list of packages; `build_portable_repo` invisibly returns
#'   the path to the created zip file.
#'
#' @details
#' Running the functions back to back performs the following steps:
#' \enumerate{
#'   \item Scans R scripts using \code{attachment::att_from_rscripts()}
#'   \item Scans Quarto files using \code{attachment::att_from_qmds()}
#'   \item Scans R Markdown files using \code{attachment::att_from_rmds()}
#'   \item Creates a package download proposal using \code{pkgdepends::new_pkg_download_proposal()}
#'   \item Resolves all package dependencies
#'   \item Downloads packages to a local repository cache
#'   \item Compresses the repository into a zip file
#' }
#'
#' @examples
#' \dontrun{
#' # Create a portable repository for Windows binaries
#' pkgs <- plan_portable_repo(path = ".")
#' build_portable_repo(pkgs)
#' }
#'
#' @export
plan_portable_repo <- function(
  path,
  add_pkgs = NULL,
  recursive = TRUE,
  write_requirements = "ask",
  verbose = TRUE
) {
  if (missing(path) && !is.character(add_pkgs)) {
    cli::cli_abort(
      "You need to provide either a {.code path} with R/Rmd/Qmd files or a vector of packages in {.code add_pkgs}."
    )
  }
  if (!is.character(add_pkgs)) {
    pkgs <- character()
  } else {
    pkgs <- add_pkgs
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
  if (write_requirements == "ask") {
    write_requirements <- utils::askYesNo(
      "Do you want to export a requirements.txt file?"
    )
  }
  if (isTRUE(write_requirements)) {
    writeLines(pkgs, "requirements.txt")
  }

  return(pkgs)
}


#' @rdname plan_portable_repo
#' @export
build_portable_repo <- function(
  pkgs,
  platforms = "windows",
  r_version = "4.5.3",
  out_file = "portable_repo.zip",
  verbose = TRUE
) {
  # TODO: check r_version and platforms are valid

  if (verbose) {
    cli::cli_progress_step(
      msg = "Downloading {length(pkgs)} packages plus dependencies",
      msg_done = "Downloaded {length(pkgs)} packages (including dependencies)"
    )
  }
  dir.create(pth <- file.path(tempdir(), "portable_repo"), showWarnings = FALSE)
  pkgs <- pkg_download(
    pkgs,
    config = list(
      cache_dir = pth,
      platforms = platforms,
      `r-versions` = r_version,
      dependencies = c("Imports", "Depends", "LinkingTo", "Suggests")
    )
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


pkg_download <- function(pkgs, config) {
  # first collect source packages to make sure all dependencies are there
  source_config <- config
  source_config$platforms <- "source"
  all_pkgs <- pkgdepends::new_pkg_download_proposal(
    refs = pkgs,
    config = source_config
  )
  all_pkgs$resolve()
  # then try to get all binaries
  dl <- pkgdepends::new_pkg_download_proposal(
    refs = all_pkgs$get_resolution()$ref,
    config = config
  )
  dl$resolve()
  solution <- dl$get_resolution()
  # if not all packages have binaries, build them
  pkgs_built <- c()
  if (any(solution$status == "FAILED")) {
    pkgs2build <- solution$ref[solution$status == "FAILED"]
    pkgs_built <- pkg_builder(
      pkgs2build,
      pth = config$cache_dir,
      r_version = config$`r-versions`
    )
    pkgs <- solution$ref[solution$status == "OK"]
    config$dependencies <- FALSE
    dl <- pkgdepends::new_pkg_download_proposal(refs = pkgs, config = config)
  }
  dl$download()
  return(c(dl$get_downloads()$ref, pkgs_built))
}
