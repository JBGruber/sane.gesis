#' Export Installation Script for Offline Use
#'
#' Copies the standalone installation script to a specified location so it can
#' be transferred to machines without the sane.gesis package installed.
#'
#' @param dest_file Character string specifying where to save the script.
#'   Default is \code{"install_minicran.r"} in the current directory.
#' @param overwrite Logical indicating whether to overwrite existing files.
#'   Default is \code{FALSE}.
#'
#' @return Invisibly returns the path to the copied file.
#'
#' @details
#' This function extracts the bundled installation script from the package
#' installation directory and copies it to a location where it can be easily
#' transferred to offline machines. The script contains the \code{install_minicran()}
#' and \code{install_minicran()} functions as standalone code that can be
#' sourced on systems without the package installed.
#'
#' The typical workflow is:
#' \enumerate{
#'   \item On a machine with internet and sane.gesis installed, run
#'         \code{export_install_script()} to get the script file
#'   \item Transfer both the script and the miniCRAN zip file to the offline machine
#'   \item On the offline machine, run \code{source("install_minicran.r")}
#'         followed by \code{install_minicran()}
#' }
#'
#' @seealso \code{\link{build_local_repo}} for creating the miniCRAN repository
#' @seealso \code{\link{install_minicran}} for the installation function
#'
#' @examples
#' \dontrun{
#' # Export to current directory
#' export_install_script()
#'
#' # Export to a specific location
#' export_install_script("S:/software/install_minicran.r")
#'
#' # Overwrite existing file
#' export_install_script(overwrite = TRUE)
#' }
#'
#' @export
export_install_script <- function(
  dest_file = "install_minicran.r",
  overwrite = FALSE
) {
  script_path <- system.file(
    "scripts",
    "install_minicran.r",
    package = "sane.gesis"
  )

  if (!file.exists(script_path)) {
    stop(
      "Installation script not found in package. ",
      "This might indicate a package installation issue."
    )
  }

  if (file.exists(dest_file) && !overwrite) {
    stop(
      "File already exists at ",
      dest_file,
      ". Use overwrite = TRUE to replace it."
    )
  }

  file.copy(script_path, dest_file, overwrite = overwrite)
  cli::cli_alert_success(
    "Installation script exported to: {.path {normalizePath(dest_file)}}"
  )
  cli::cli_alert_info("To use on an offline machine:")
  cli::cli_div(theme = list(ol = list("margin-left" = 2)))
  cli::cli_ol(c(
    "Copy this file and your miniCRAN zip to the target machine",
    "Run: source('FILE_LOCATION')",
    "Run: install_minicran()"
  ))

  invisible(dest_file)
}
