
<!-- README.md is generated from README.Rmd. Please edit that file -->

# sane.gesis

<!-- badges: start -->

<!-- badges: end -->

Create and install from portable package repositories for offline R
package management in restricted network environments.

## Overview

`sane.gesis` provides a streamlined workflow for managing R packages in
environments without direct internet access. It automates the process
of:

1.  Detecting package dependencies from your R scripts, Quarto, and R
    Markdown files
2.  Downloading all required packages and their dependencies from CRAN
    in the correct format for SANE
3.  Creating a compressed, portable package repository
4.  Installing packages from the compressed repository on machines
    without internet access

This is particularly useful for users and admionistrators of the SecDC
instances at SANE (Secure ANalysis Environment)

## Installation

You can install the development version of sane.gesis from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("JBGruber/sane.gesis")
```

## Usage

### Creating a Portable Package Repository

Use `plan_portable_repo()` to scan your project directory and find all
packages that you have used in a project (and their dependencies). As
example, we run in on the folder R, to do the same for the current
working directory, you can run `plan_portable_repo(".")`:

``` r
library(sane.gesis)
# scan folder called R
plan_portable_repo("R")
#> ℹ Checking R scripts for packages
#> ✔ Checked R scripts for packages [npkgs = 5] [196ms]
#>
#> ℹ Checking Quarto files for packages
#> ✔ Checked Quarto files for packages [npkgs = 5] [25ms]
#>
#> ℹ Checking R Markdown files for packages
#> ✔ Checked R Markdown files for packages [npkgs = 5] [10ms]
#>
#> [1] "cli"        "attachment" "zip"        "pkgdepends" "utils"
```

The function will:

- Scan all R scripts, Quarto files (`.qmd`), and R Markdown files
  (`.Rmd`) in the directory
- Identify all package dependencies using the `attachment` package
- Resolve transitive dependencies using `pkgdepends`

The resulting vector can be sent to the person who manages the offline
machine and can add files. They can then build a portable repository
using `build_portable_repo()`:

``` r
plan_portable_repo("R") |>
  build_portable_repo()
#> ℹ Checking R scripts for packages
#> ✔ Checked R scripts for packages [npkgs = 5] [9ms]
#>
#> ℹ Checking Quarto files for packages
#> ✔ Checked Quarto files for packages [npkgs = 5] [8ms]
#>
#> ℹ Checking R Markdown files for packages
#> ✔ Checked R Markdown files for packages [npkgs = 5] [5ms]
#>
#> ℹ Downloading 5 packages plus dependencies
#> ✔ Downloaded 91 packages (including dependencies) [2.2s]
#>
#> ℹ Compressing packages
#> ✔ Compressed 91 packages into 'portable_repo.zip' [2.4s]
```

- Download packages from CRAN
- Create a compressed zip file containing the complete repository
- The package defaults reflect the system that SANE is currently running

### Installing from a Portable Package Repository

Once you’ve transferred the zip file to your offline system, you can
install packages in two ways:

#### Option 1: Install All Packages from Zip Archive

``` r
# Install all packages from the compressed repository
install_portable_repo()
```

This will:

- Extract packages to your user library directory
- Skip packages that are already installed
- Display progress as packages are installed

#### Option 2: Install Specific Packages from Local Repository

If you do not want (re)install all packages, but only specific ones, you
can pass a selection:

``` r
# Install specific packages
install_portable_repo(pkgs = "dplyr")
install_portable_repo(pkgs = c("ggplot2", "tidyr", "readr"))
```

Note: This is not recommended as the function will not resolve
dependencies, which means that your packages will likely not work (you
can use the function to install dependencies though).

## Workflow

### On One or Multiple Machines with Internet Access

1.  Install the sane.gesis package and create a portable package
    repository:

``` r
library(sane.gesis)

# Collect packages to install
package_list <- plan_portable_repo(".")

# Create the package repository (this can happen on a different machine)
build_portable_repo(package_list)

# Export the installation script
export_install_script()
```

2.  Transfer both files to the *SANE Data Provider Portal* machine:
    - `portable_repo.zip` (the package repository)
    - `install_portable_repo.r` (the installation script)

### On the SANE Tinker Device

3.  Access the SANE tinker device and run:

``` r
source('S:/software/install_portable_repo.r')
install_portable_repo()
```

The `export_install_script()` function extracts the standalone
installation script from the package, making it easy to transfer to
machines without the package installed.

## Technical Details

### Package Detection

The package scans for dependencies using the `attachment` package, which
recognizes:

- `library()`, `require()` and `::` calls in R scripts
- YAML headers and inline code in Quarto files
- YAML headers and R chunks in R Markdown files

Package dependencies are resolved and downloaded using the `pkgdepends`
package, which provides robust dependency resolution and supports
multiple platforms and R versions.

### Repository Structure

The created zip file contains a standard CRAN-style repository
structure:

    bin/
      windows/
        contrib/
          4.3/
            package1_1.0.0.zip
            package2_2.1.0.zip
            ...
            PACKAGES
            PACKAGES.gz

### Windows-Specific Design

The current implementation is optimized for Windows binary packages and
uses a two-step unzipping process (since Windows packages are themselves
zip files) – which is ideal for SANE Tinker machines. The approach can
be adapted for other platforms by changing the `type` parameter.

## License

MIT + file LICENSE
