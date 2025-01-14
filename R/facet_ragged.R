#' Lay out panels in a ragged grid
#'
#' These facets create layouts in-between [ggplot2::facet_wrap()] and
#' [ggplot2::facet_grid()]. Panels are arranged into groups stacked along the
#' defining dimension, but remain independent in the other dimension, allowing
#' for a grid with ragged edges. This can be useful, for example, to represent
#' nested or partially crossed relationships between faceting variables.
#'
#' @param rows,cols A set of variables or expressions quoted by [ggplot2::vars()],
#'   the combinations of which define the panels in the layout.
#' @param ... Arguments reserved for future use.
#' @param scales Determines which panels share axis ranges. By default (`"fixed"`),
#'   all panels share the same scales. Use `"free_x"` to let x-axes vary, use
#'   `"free_y"` to let y-axes vary, or `"free"` to let both axes vary. Panels
#'   within groups always share the scale along the grouping dimension.
#' @param switch Determines how facet label strips are positioned. By default
#'   (`"none"`), strips are drawn to the top and right of the panels. Use `"x"`
#'   to switch the top strip to the bottom, use `"y"` to switch the right strip
#'   to the left, or `"both"` to do both.
#' @param strips Determines which facet label strips are drawn. By default
#'   (`"margins"`), strips between panels along the grouping dimension will be
#'   suppressed. Use `"all"` to always draw both strips.
#' @param axes Determines which axes are drawn. By default (`"margins"`), axes
#'   between panels will be suppressed if they are fixed. Use `"all_x"` to
#'   always draw x-axes, `"all_y"` to always draw y-axes, or `"all"` to always
#'   draw both axes.
#' @param align Determines how panels are positioned within groups. By default
#'   (`"start"`), panels in groups are densely packed from the start. Use
#'   `"end"` to instead pack panels to the end of the group.
#' @inheritParams ggplot2::facet_wrap
#'
#' @returns A `Facet` that can be added to a `ggplot`.
#'
#' @examples
#' p <- ggplot(mpg, aes(displ, cty)) + geom_point()
#' p + facet_ragged_rows(vars(drv), vars(cyl))
#' p + facet_ragged_cols(vars(cyl), vars(drv))
#' \donttest{
#' # Allow axes to vary between panels
#' p + facet_ragged_rows(vars(drv), vars(cyl), scales = "free_y")
#' p + facet_ragged_rows(vars(drv), vars(cyl), scales = "free")
#'
#' # Change strip label positions
#' p + facet_ragged_rows(vars(drv), vars(cyl), switch = "y")
#' p + facet_ragged_rows(vars(drv), vars(cyl), switch = "both")
#'
#' # Draw strips between panels
#' p + facet_ragged_rows(vars(drv), vars(cyl), strips = "all")
#'
#' # Draw axes between panels
#' p + facet_ragged_rows(vars(drv), vars(cyl), axes = "all_x")
#' p + facet_ragged_rows(vars(drv), vars(cyl), axes = "all")
#' }
#' # Change panel alignment
#' p + facet_ragged_rows(vars(drv), vars(cyl), align = "end")
#' @name facet_ragged
NULL

FacetRagged <- ggproto("FacetRagged", Facet,
  shrink = TRUE,

  setup_params = function(data, params) {
    params <- Facet$setup_params(data, params)
    params$rows <- rlang::quos_auto_name(params$rows)
    params$cols <- rlang::quos_auto_name(params$cols)
    params$free <- list(
      x = params$scales %in% c("free_x", "free"),
      y = params$scales %in% c("free_y", "free")
    )
    params$switch <- list(
      x = params$switch %in% c("x", "both"),
      y = params$switch %in% c("y", "both")
    )
    params$axes <- list(
      x = params$axes %in% c("all_x", "all"),
      y = params$axes %in% c("all_y", "all")
    )
    params$strip.position <- c(
      if (params$switch$x) "bottom" else "top",
      if (params$switch$y) "left" else "right"
    )
    params
  },

  map_data = function(data, layout, params) {
    FacetGrid$map_data(data, layout, params)
  },

  vars = function(self) {
    names(c(self$params$rows, self$params$cols))
  },

  draw_panels = function(self, panels, layout, x_scales, y_scales, ranges, coord, data, theme, params) {
    table <- self$init_gtable(panels, layout, ranges, coord, theme, params)
    table <- self$attach_axes(table, layout, ranges, coord, theme, params)
    table <- self$attach_strips(table, layout, theme, params)
    table <- self$finalise_gtable(table, layout, params)
    table
  },

  init_gtable = function(panels, layout, ranges, coord, theme, params) {
    if (!coord$is_free() && (params$free$x || params$free$y))
      stop("Can't use free scales with a fixed coordinate system.")
    aspect_ratio <- theme$aspect.ratio %||% coord$aspect(ranges[[1]])

    # Create an empty table with dimensions from layout
    rows_count <- max(layout$ROW)
    cols_count <- max(layout$COL)
    widths <- rep(unit(1, "null"), cols_count)
    heights <- rep(unit(aspect_ratio %||% 1, "null"), rows_count)
    table <- gtable(widths, heights, respect = !is.null(aspect_ratio))

    # Insert panel grobs according to layout and add spacing
    panel_name <- sprintf("panel-%d", layout$PANEL)
    table <- gtable_add_grob(table, panels, layout$ROW, layout$COL, name = panel_name)
    table <- gtable_add_col_space(table, calc_element("panel.spacing.x", theme))
    table <- gtable_add_row_space(table, calc_element("panel.spacing.y", theme))

    table
  },

  attach_axes = function(table, layout, ranges, coord, theme, params) {
    axes <- render_unique_axes(layout, ranges, coord, theme)
    axes <- list(
      t = lapply(axes$x, `[[`, "top"),
      b = lapply(axes$x, `[[`, "bottom"),
      l = lapply(axes$y, `[[`, "left"),
      r = lapply(axes$y, `[[`, "right")
    )
    add_panel_decorations(table, layout, axes, kind = "axis")
  },

  attach_strips = function(table, layout, theme, params) {
    # Render strips with faceting variable data
    cols_data <- layout[names(params$cols)]
    rows_data <- layout[names(params$rows)]
    strips <- render_unique_strips(cols_data, rows_data, params$labeller, theme)
    strips <- c(strips$x, strips$y)

    # Zero out strips which shouldn't be added
    for (side in c("top", "bottom", "left", "right"))
      if (!side %in% params$strip.position)
        strips[[side]][] <- list(zeroGrob())

    # Make strips stick correctly in zero-sized rows/cols
    for (side in c("top", "bottom", "left", "right"))
      strips[[side]] <- lapply(strips[[side]], set_strip_viewport, side)

    add_panel_decorations(table, layout, strips, kind = "strip")
  }
)

render_unique_axes <- function(layout, ranges, coord, theme) {
  if (inherits(coord, "CoordFlip")) {
    # Switch the scales back
    layout[c("SCALE_X", "SCALE_Y")] <- layout[c("SCALE_Y", "SCALE_X")]
  }

  # Identify groups
  SCALE_X <- match(layout$SCALE_X, unique(layout$SCALE_X))
  SCALE_Y <- match(layout$SCALE_Y, unique(layout$SCALE_Y))

  # Render representatives
  x_rep <- ranges[match(unique(SCALE_X), SCALE_X)]
  y_rep <- ranges[match(unique(SCALE_Y), SCALE_Y)]
  axes <- render_axes(x_rep, y_rep, coord, theme)

  # Distribute to groups
  axes$x <- axes$x[SCALE_X]
  axes$y <- axes$y[SCALE_Y]
  axes
}

render_unique_strips <- function(x, y, labeller, theme) {
  # Identify groups
  STRIP_X <- vctrs::vec_match(x, vctrs::vec_unique(x))
  STRIP_Y <- vctrs::vec_match(y, vctrs::vec_unique(y))

  # Render representatives
  x_rep <- vctrs::vec_slice(x, match(unique(STRIP_X), STRIP_X))
  y_rep <- vctrs::vec_slice(y, match(unique(STRIP_Y), STRIP_Y))
  strips <- render_strips(x_rep, y_rep, labeller, theme)

  # Distribute to groups
  strips$x <- lapply(strips$x, function(x) x[STRIP_X])
  strips$y <- lapply(strips$y, function(y) y[STRIP_Y])
  strips
}

add_panel_decorations <- function(table, layout, grobs, kind) {
  kind <- rlang::arg_match0(kind, c("axis", "strip"))

  # Add rows for horizontal decorations
  height_t <- max_height(grobs$t)
  height_b <- max_height(grobs$b)
  for (t in sort(panel_rows(table)$t, decreasing = TRUE)) {
    table <- gtable_add_rows(table, height_t, t - 1)
    table <- gtable_add_rows(table, height_b, t + 1)
  }

  # Add columns for vertical decorations
  width_l <- max_width(grobs$l)
  width_r <- max_width(grobs$r)
  for (l in sort(panel_cols(table)$l, decreasing = TRUE)) {
    table <- gtable_add_cols(table, width_l, l - 1)
    table <- gtable_add_cols(table, width_r, l + 1)
  }

  # Find panel positions after layout changes
  panel_pos <- gtable_get_grob_position(table, sprintf("panel-%d", layout$PANEL))

  # Add decorations around panels
  table <- gtable_add_grob(table, grobs$t, panel_pos$t - 1, panel_pos$l, name = sprintf("%s-t-%d", kind, layout$PANEL))
  table <- gtable_add_grob(table, grobs$b, panel_pos$b + 1, panel_pos$l, name = sprintf("%s-b-%d", kind, layout$PANEL))
  table <- gtable_add_grob(table, grobs$l, panel_pos$t, panel_pos$l - 1, name = sprintf("%s-l-%d", kind, layout$PANEL))
  table <- gtable_add_grob(table, grobs$r, panel_pos$t, panel_pos$r + 1, name = sprintf("%s-r-%d", kind, layout$PANEL))

  table
}

cull_inner_panel_decorations <- function(table, layout, sides, kind) {
  kind <- rlang::arg_match0(kind, c("axis", "strip"))
  for (side in sides) {
    # Remove grobs from inner panels
    panels <- panels_with_neighbour(layout, side)
    names <- sprintf("%s-%s-%d", kind, side, panels)
    table <- gtable_set_grobs(table, names, list(zeroGrob()))

    # And the space allocated for them
    table <- switch(
      side,
      t = ,
      b = gtable_set_height(table, names, unit(0, "cm")),
      l = ,
      r = gtable_set_width(table, names, unit(0, "cm")),
      stop("internal error: invalid side: ", side)
    )

    # Shift axes at inner margins to start at strip edge. It would be much
    # cleaner to have the axes attached to the strips, but that doesn't play
    # nicely with how ggplot2 expects the axes to be present in the gtable.
    if (kind == "strip")
      table <- shift_inner_margin_axes(table, layout, side)
  }
  table
}

shift_inner_margin_axes <- function(table, layout, side) {
  for (panel in inner_margin_panels(layout, side)) {
    # Get the strip and axis, bailing if either isn't there
    strip_name <- sprintf("strip-%s-%d", side, panel)
    strip <- gtable_get_grob(table, strip_name)
    if (is.null(strip) || inherits(strip, "zeroGrob")) next

    axis_name <- sprintf("axis-%s-%d", side, panel)
    axis <- gtable_get_grob(table, axis_name)
    if (is.null(axis) || inherits(axis, "zeroGrob")) next

    # Shift the axis to start at the edge of the strip
    axis <- switch(
      side,
      t = grob_shift_viewport(axis, y = +grid::grobHeight(strip)),
      b = grob_shift_viewport(axis, y = -grid::grobHeight(strip)),
      l = grob_shift_viewport(axis, x = -grid::grobWidth(strip)),
      r = grob_shift_viewport(axis, x = +grid::grobWidth(strip)),
      stop("internal error: invalid side: ", side)
    )
    table <- gtable_set_grobs(table, axis_name, list(axis))
  }
  table
}

set_strip_viewport <- function(strip, side) {
  strip$vp <- switch(
    substr(side, 1, 1),
    # TODO: `clip = "off"` not needed in ggplot2 dev version (3.5.1.9000), could be removed in the future.
    t = grid::viewport(clip = "off", height = grid::grobHeight(strip), y = unit(0, "npc"), just = "bottom"),
    b = grid::viewport(clip = "off", height = grid::grobHeight(strip), y = unit(1, "npc"), just = "top"),
    l = grid::viewport(clip = "off", width = grid::grobWidth(strip), x = unit(1, "npc"), just = "right"),
    r = grid::viewport(clip = "off", width = grid::grobWidth(strip), x = unit(0, "npc"), just = "left"),
    stop("internal error: invalid side: ", side)
  )
  strip
}
