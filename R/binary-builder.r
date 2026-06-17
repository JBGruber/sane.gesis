#' Build or obtain Windows binaries for packages missing from CRAN
#'
#' @param pkgs Character vector of package names or refs understood by
#'   `pkgdepends`.
#' @param pth Path to the portable repo root. Binaries are placed under
#'   `pth/bin/windows/contrib/<r_minor>/`.
#' @param r_version R version string, e.g. `"4.5.3"`. Used to select the
#'   correct win-builder endpoint and output directory.
#' @param platform Target platform the binaries are built for (a `pkgdepends`
#'   platform name, e.g. `"windows"`). Packages that need compilation can only
#'   be built when the current machine runs this same OS; otherwise they are
#'   skipped with a warning.
#' @return Invisibly returns the number of binaries that were built.
#' @export
pkg_builder <- function(
  pkgs,
  pth,
  r_version = "4.5.3",
  platform = "windows"
) {
  source_pth <- file.path(pth, "_source_cache")
  dir.create(source_pth, showWarnings = FALSE, recursive = TRUE)

  dl <- pkgdepends::new_pkg_download_proposal(
    refs = pkgs,
    config = list(
      cache_dir = source_pth,
      platforms = "source",
      `r-versions` = r_version,
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
  # When the current machine runs the target OS, it has the toolchain to
  # compile packages locally; otherwise compiled packages must be skipped.
  can_compile <- host_matches_platform(platform)
  pkg_out <- 0
  for (f in source_files) {
    info <- pkg_desc_info(f)
    if (isTRUE(info$unix_only) && !identical(platform, "linux")) {
      cli::cli_alert_danger(
        "{basename(f)} is a Unix-only package and cannot be included"
      )
      next
    }
    if (info$needs_compilation && !can_compile) {
      cli::cli_alert_danger(
        "{basename(f)} requires compilation, which can only be done on a {platform} machine. This package was skipped."
      )
      next
    }
    cli::cli_progress_step(
      msg = "Building Windows binary for {basename(f)}",
      msg_done = "Built Windows binary for {basename(f)}"
    )
    build_windows_binary(f, bin_dir)
    pkg_out <- pkg_out + 1
  }

  invisible(pkg_out)
}


# Does the current machine run the target platform's OS? Only then can it
# natively compile packages for that platform.
host_matches_platform <- function(platform) {
  host <- switch(
    Sys.info()[["sysname"]],
    Windows = "windows",
    Darwin = "macos",
    Linux = "linux",
    tolower(Sys.info()[["sysname"]])
  )
  platform <- switch(
    tolower(platform),
    mac = "macos",
    osx = "macos",
    macosx = "macos",
    tolower(platform)
  )
  identical(host, platform)
}


# Read the DESCRIPTION of a source tarball and report whether it needs
# compilation and whether it is Unix-only. Extracts only DESCRIPTION to a
# temp dir and reads it. If unsure, assumes compilation is needed.
pkg_desc_info <- function(tarball) {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  utils::untar(tarball, exdir = tmp)
  pkg_dir <- dir(tmp, full.names = TRUE)[1L]
  desc_file <- file.path(pkg_dir, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    return(list(needs_compilation = TRUE, unix_only = FALSE))
  } # assume yes if unsure

  desc <- read.dcf(desc_file)
  os_type <- as.character(try(desc[1L, "OS_type"], silent = TRUE))
  list(
    needs_compilation = identical(
      as.character(desc[1L, "NeedsCompilation"]),
      "yes"
    ),
    unix_only = identical(os_type, "unix")
  )
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
