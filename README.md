# sane.gesis

<!-- badges: start -->
<!-- badges: end -->

Create and install from miniCRAN repositories for offline R package management in restricted network environments.

## Overview

`sane.gesis` provides a streamlined workflow for managing R packages in environments without direct internet access. It automates the process of:

1. Detecting package dependencies from your R scripts, Quarto, and R Markdown files
2. Downloading all required packages and their dependencies from CRAN in the correct format for SANE
3. Creating a compressed, portable miniCRAN repository
4. Installing packages from the compressed repository on machines without internet access

This is particularly useful for users and admionistrators of the SecDC instances at SANE (Secure ANalysis Environment)

## Installation

You can install the development version of sane.gesis from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("JBGruber/sane.gesis")
```

## Usage

### Creating a miniCRAN Repository

Use `build_minicran_repo()` to scan your project directory and create a compressed repository:

``` r
library(sane.gesis)

# Create a repository with Windows binaries for R 4.3
build_minicran_repo(
  path = "."
)
```

The function will:

- Scan all R scripts, Quarto files (`.qmd`), and R Markdown files (`.Rmd`) in the directory
- Identify all package dependencies using the `attachment` package
- Resolve transitive dependencies using `miniCRAN`
- Download packages from CRAN
- Create a compressed zip file containing the complete repository

### Installing from a miniCRAN Repository

Once you've transferred the zip file to your offline system, you can install packages in two ways:

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

If you have an uncompressed miniCRAN repository at a fixed location:

``` r
# Install specific packages
install_from_minicran("dplyr")
install_from_minicran(c("ggplot2", "tidyr", "readr"))
```

Note: This function expects the repository to be at `file:///S:/software/miniCRAN` by default.

## Workflow

### On a Machine with Internet Access

1. Install the sane.gesis package and create a miniCRAN repository:

``` r
library(sane.gesis)

# Create the package repository
build_minicran_repo(path = ".")

# Export the installation script
export_install_script()
```

2. Transfer both files to the *SANE Data Provider Portal* machine:
   - `mincran_repo.zip` (the package repository)
   - `install_from_minicran.r` (the installation script)

### On the SANE Tinker Device

3. Access the SANE tinker device and run:

``` r
source('S:/software/install_from_minicran.r')
install_minicran()
```

The `export_install_script()` function extracts the standalone installation script from the package, making it easy to transfer to machines without the package installed.


## Technical Details

### Package Detection

The package scans for dependencies using the `attachment` package, which recognizes:

- `library()` and `require()` calls in R scripts
- YAML headers and inline code in Quarto files
- YAML headers and R chunks in R Markdown files

### Repository Structure

The created zip file contains a standard miniCRAN structure:

```
bin/
  windows/
    contrib/
      4.3/
        package1_1.0.0.zip
        package2_2.1.0.zip
        ...
        PACKAGES
        PACKAGES.gz
```

### Windows-Specific Design

The current implementation is optimized for Windows binary packages and uses a two-step unzipping process (since Windows packages are themselves zip files) -- which is ideal for SANE Tinker machines. The approach can be adapted for other platforms by changing the `type` parameter. 

## License

MIT + file LICENSE
