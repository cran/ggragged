## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.dpi = 96,
  fig.width = 7.0,
  fig.height = 4.5
)

## ----setup--------------------------------------------------------------------
library(ggragged)

## ----sad-data-----------------------------------------------------------------
data(Theoph)

Theoph2 <- transform(Theoph, Cohort = (as.numeric(Subject) - 1) %% 3 + 1)
Theoph2 <- transform(Theoph2, Subject = (as.numeric(Subject) - 1) %/% 3 + 1)
Theoph2 <- transform(Theoph2, Subject = sprintf("%d0%d", Cohort, Subject))
Theoph2 <- transform(Theoph2, conc = conc * 2^(Cohort - 1))
Theoph2 <- subset(Theoph2, Subject != "204")

with(Theoph2, table(Cohort, Subject))

## ----sad-wrap-----------------------------------------------------------------
p <- ggplot(Theoph2, aes(Time, conc)) + geom_line()
p + facet_wrap(vars(Subject, Cohort), labeller = label_both)

## ----sad-ragged---------------------------------------------------------------
p + facet_ragged_rows(vars(Cohort), vars(Subject), labeller = label_both)

## ----sad-ragged-free----------------------------------------------------------
p + facet_ragged_rows(vars(Cohort), vars(Subject), labeller = label_both, scales = "free_y")

## ----gun-data-----------------------------------------------------------------
data(Gun, package = "nlme")
with(Gun, table(Method, Team, Physique))

## ----gun-grid-----------------------------------------------------------------
p <- ggplot(Gun, aes(Method, rounds)) + geom_point()
p + facet_grid(vars(Team = substr(Team, 1, 2)), vars(Physique), labeller = label_both)

## ----gun-ragged---------------------------------------------------------------
p + facet_ragged_cols(vars(Team), vars(Physique), labeller = label_both)

