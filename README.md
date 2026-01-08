
<!-- README.md is generated from README.Rmd. Please edit that file -->

# sane.gesis

<!-- badges: start -->

<!-- badges: end -->

Create and install from miniCRAN repositories for offline R package
management in restricted network environments.

## Overview

`sane.gesis` provides a streamlined workflow for managing R packages in
environments without direct internet access. It automates the process
of:

1.  Detecting package dependencies from your R scripts, Quarto, and R
    Markdown files
2.  Downloading all required packages and their dependencies from CRAN
    in the correct format for SANE
3.  Creating a compressed, portable miniCRAN repository
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

### Creating a miniCRAN Repository

Use `plan_local_repo()` to scan your project directory and find all
packages that you have used in a project (and their dependencies):

``` r
library(sane.gesis)
plan_local_repo(".")
#> ✔ Checked R scripts for packages [npkgs = 5] [153ms]
#> ✔ Checked Quarto files for packages [npkgs = 5] [23ms]
#> ✔ Checked R Markdown files for packages [npkgs = 5] [9ms]
#> ✔ Queried for package dependencies [npkgs = 2289] [7.5s]
#>
#>    [1] "cli"                        "attachment"
#>    [3] "miniCRAN"                   "zip"
#>    [5] "desc"                       "glue"
#>    [7] "knitr"                      "magrittr"
#> ...
```

The function will:

- Scan all R scripts, Quarto files (`.qmd`), and R Markdown files
  (`.Rmd`) in the directory
- Identify all package dependencies using the `attachment` package
- Resolve transitive dependencies using `miniCRAN`

The resulting vector can be sent to the person who manages the offline
machine and can add files. They can then build a local repository using
`build_local_repo()`:

``` r
plan_local_repo(".") |>
  build_local_repo()
#> ✔ Checked R scripts for packages [npkgs = 5] [5ms]
#> ✔ Checked Quarto files for packages [npkgs = 5] [7ms]
#> ✔ Checked R Markdown files for packages [npkgs = 5] [5ms]
#> ✔ Queried for package dependencies [npkgs = 2289] [7.1s]
#> ✔ Downloaded packages [1m 12.1s]
#> ✔ Compressed 2289 packages into 'mincran_repo.zip' [1m 1.4s]
#>
```

- Download packages from CRAN
- Create a compressed zip file containing the complete repository
- The package defaults reflect the system that SANE is currently running

### Installing from a miniCRAN Repository

Once you’ve transferred the zip file to your offline system, you can
install packages in two ways:

#### Option 1: Install All Packages from Zip Archive

``` r
# Install all packages from the compressed repository
install_minicran()
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
install_minicran(pkgs = "dplyr")
install_minicran(pkgs = c("ggplot2", "tidyr", "readr"))
```

Note: This is not recommended as the function will not resolve
dependencies, which means that your packages will likely not work (you
can use the function to install dependencies though).

## Workflow

### On One or Multiple Machines with Internet Access

1.  Install the sane.gesis package and create a miniCRAN repository:

``` r
library(sane.gesis)

# Collect packages to install
package_list <- plan_local_repo(".")

# Create the package repository (this can happen on a different machine)
build_local_repo(package_list)

# Export the installation script
export_install_script()
```

2.  Transfer both files to the *SANE Data Provider Portal* machine:
    - `mincran_repo.zip` (the package repository)
    - `install_minicran.r` (the installation script)

### On the SANE Tinker Device

3.  Access the SANE tinker device and run:

``` r
source('S:/software/install_minicran.r')
install_minicran()
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

### Repository Structure

The created zip file contains a standard miniCRAN structure:

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
