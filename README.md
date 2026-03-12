
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

This is particularly useful for users and administrators of the Secure Data Center (SecDC)
instances at SANE (Secure ANalysis Environment).

## Installation

You can install the development version of sane.gesis from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("JBGruber/sane.gesis")
```

## Usage

### Creating a Portable Package Repository

Use `plan_portable_repo()` to scan your project directory and find all
packages that you have used in a project (and their dependencies). As an
example, we run in on the folder R. To do the same for the current
working directory you are working in, you can run `plan_portable_repo(".")`.

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

After running this code, you will be automatically asked whether you want to export a "requirements.txt" file. Please select "Yes", which will create the file "requirements.txt" in your working directory. This file contains the names of all the packages that were found by `plan_portable_repo(".")`. This document can be sent to the person who manages the offline
machine and can add files. They can then build a portable repository
using `build_portable_repo()`. That means you don't have to run the
following chunk of code yourself -- the person working at the Secure Data Center will do that:

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
