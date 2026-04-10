#' Build or obtain Windows binaries for packages missing from CRAN
#'
#' @param pkgs Character vector of package names or refs understood by
#'   `pkgdepends`.
#' @param pth Path to the portable repo root. Binaries are placed under
#'   `pth/bin/windows/contrib/<r_minor>/`.
#' @param r_version R version string, e.g. `"4.3.2"`. Used to select the
#'   correct win-builder endpoint and output directory.
#' @param mirror CRAN mirror URL.
#' @return Invisibly returns the path to the binary output directory.
#' @export
pkg_builder <- function(
  pkgs,
  pth,
  r_version = "4.3.2",
  mirror = "https://cloud.r-project.org"
) {
  source_pth <- file.path(pth, "_source_cache")
  dir.create(source_pth, showWarnings = FALSE, recursive = TRUE)

  dl <- pkgdepends::new_pkg_download_proposal(
    refs = pkgs,
    config = list(
      cache_dir = source_pth,
      platforms = "source",
      `r-versions` = r_version,
      cran_mirror = mirror,
      dependencies = FALSE
    )
  )
  dl$resolve()
  solution <- dl$get_resolution()

  if (any(solution$status == "FAILED")) {
    cli::cli_alert_danger(
      "Some packages are not available on CRAN and will be skipped: {.code {solution$ref[solution$status == 'FAILED']}}"
    )
    dl <- pkgdepends::new_pkg_download_proposal(
      refs = solution$ref[solution$status == 'OK'],
      config = list(
        cache_dir = source_pth,
        platforms = "source",
        `r-versions` = r_version,
        cran_mirror = mirror,
        dependencies = FALSE
      )
    )
    dl$resolve()
  }

  dl$download()

  source_files <- dir(
    source_pth,
    pattern = "\\.tar\\.gz$",
    recursive = TRUE,
    full.names = TRUE
  )

  r_minor <- paste(numeric_version(r_version)[1L, 1:2], collapse = ".")
  bin_dir <- file.path(pth, "bin", "windows", "contrib", r_minor)
  dir.create(bin_dir, showWarnings = FALSE, recursive = TRUE)
  pkg_out <- 0
  for (f in source_files) {
    if (!pkg_needs_compilation(f)) {
      cli::cli_progress_step(
        msg = "Building Windows binary for {basename(f)}",
        msg_done = "Built Windows binary for {basename(f)}"
      )
      build_windows_binary(f, bin_dir)
      pkg_out <- pkg_out + 1
    }
  }

  invisible(pkg_out)
}


# Check whether a source tarball declares NeedsCompilation: yes.
# Extracts only DESCRIPTION to a temp dir and reads it.
pkg_needs_compilation <- function(tarball) {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  utils::untar(tarball, exdir = tmp)
  pkg_dir <- dir(tmp, full.names = TRUE)[1L]
  desc_file <- file.path(pkg_dir, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    return(TRUE)
  } # assume yes if unsure

  desc <- read.dcf(desc_file)
  # special case, not available for all OS
  if (identical(as.character(desc[1L, "OS_type"]), "unix")) {
    cli::cli_alert_danger(
      "{basename(f)} is a Unix-only package and cannot be included"
    )
    return(TRUE)
  }
  if (identical(as.character(desc[1L, "NeedsCompilation"]), "yes")) {
    cli::cli_alert_danger(
      "{basename(f)} requires compilation. This cannot be done yet"
    )
    return(TRUE)
  }
  return(FALSE)
}


# Install a source tarball locally and repackage the result as a Windows
# binary zip. Only appropriate for packages where NeedsCompilation is "no".
build_windows_binary <- function(tarball, bin_dir) {
  tmp_src <- tempfile()
  tmp_lib <- tempfile()
  dir.create(tmp_src, recursive = TRUE)
  dir.create(tmp_lib, recursive = TRUE)
  on.exit({
    unlink(tmp_src, recursive = TRUE)
    unlink(tmp_lib, recursive = TRUE)
  })

  utils::untar(tarball, exdir = tmp_src)
  pkg_source_dir <- dir(tmp_src, full.names = TRUE)[1L]

  utils::install.packages(
    pkg_source_dir,
    lib = tmp_lib,
    repos = NULL,
    type = "source",
    quiet = TRUE
  )

  pkg_name <- basename(pkg_source_dir)
  installed_dir <- file.path(tmp_lib, pkg_name)

  desc <- read.dcf(file.path(installed_dir, "DESCRIPTION"))
  version <- desc[1L, "Version"]
  pkg_name <- desc[1L, "Package"]

  zip_name <- paste0(pkg_name, "_", version, ".zip")
  zip::zip(
    zipfile = file.path(bin_dir, zip_name),
    files = pkg_name,
    root = tmp_lib
  )

  invisible(file.path(bin_dir, zip_name))
}
