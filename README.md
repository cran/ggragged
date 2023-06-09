
<!-- README.md is generated from README.Rmd. Please edit that file -->

# ggragged <a href="https://mikmart.github.io/ggragged/"><img src="man/figures/logo.png" align="right" height="139" /></a>

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/mikmart/ggragged/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mikmart/ggragged/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/mikmart/ggragged/branch/main/graph/badge.svg)](https://app.codecov.io/gh/mikmart/ggragged?branch=main)
<!-- badges: end -->

ggragged extends the faceting system in
[ggplot2](https://ggplot2.tidyverse.org/) to ragged grids – a hybrid
layout between `facet_wrap()` and `facet_grid()`.

- `facet_ragged_rows()` groups panels into rows of (potentially) varying
  lengths.
- `facet_ragged_cols()` groups panels into columns of (potentially)
  varying lengths.

## Installation

Install the current release from [CRAN](https://cran.r-project.org/):

``` r
install.packages("ggragged")
```

Or the development version from
[GitHub](https://github.com/mikmart/ggragged/):

``` r
remotes::install_github("mikmart/ggragged")
```

## Example

Ragged grids can be used to clearly separate nested hierarchies in the
panel layout:

``` r
library(ggplot2)
library(ggragged)

p <- ggplot(Indometh, aes(time, conc)) + geom_line()

# Panels for each subject, with cohorts on separate rows
p + facet_ragged_rows(
 vars(Cohort = 1 + Subject %in% 3:6),
 vars(Subject = as.character(Subject)),
 labeller = label_both
)
```

<img src="man/figures/README-example-1.png" width="100%" />

``` r
# Panels for each subject, with cohorts in separate columns
p + facet_ragged_cols(
 vars(Subject = as.character(Subject)),
 vars(Cohort = 1 + Subject %in% 3:6),
 labeller = label_both
)
```

<img src="man/figures/README-example-2.png" width="100%" />
