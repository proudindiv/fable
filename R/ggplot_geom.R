blendHex <- function(mixcol, seqcol, alpha=1) {
  if(!requireNamespace("colorspace")){
    abort('The `colorspace` package is missing, please install it using `install.packages("colorspace")`')
  }
  if (all(is.na(seqcol))) {
    return(mixcol)
  }
  
  # transform to hue/lightness/saturation colorspace
  seqcol <- grDevices::col2rgb(seqcol, alpha = TRUE)
  mixcol <- grDevices::col2rgb(mixcol, alpha = TRUE)
  seqcolHLS <- suppressWarnings(colorspace::coerce(colorspace::RGB(R = seqcol[1, ] / 255, G = seqcol[2, ] / 255, B = seqcol[3, ] / 255), structure(NULL, class = "HLS")))
  mixcolHLS <- suppressWarnings(colorspace::coerce(colorspace::RGB(R = mixcol[1, ] / 255, G = mixcol[2, ] / 255, B = mixcol[3, ] / 255), structure(NULL, class = "HLS")))
  
  # copy luminence
  mixcolHLS@coords[, "L"] <- seqcolHLS@coords[, "L"]
  mixcolHLS@coords[, "S"] <- alpha * mixcolHLS@coords[, "S"] + (1 - alpha) * seqcolHLS@coords[, "S"]
  mixcolHex <- suppressWarnings(colorspace::coerce(mixcolHLS, structure(NULL, class = "RGB")))
  mixcolHex <- colorspace::hex(mixcolHex)
  mixcolHex <- ggplot2::alpha(mixcolHex, mixcol[4, ] / 255)
  return(mixcolHex)
}

#' @rdname geom_forecast
#' @export
GeomForecast <- ggplot2::ggproto("GeomForecast", ggplot2::Geom,
                                 required_aes = c("x", "y"),
                                 optional_aes = c("ymin", "ymax", "level"),
                                 default_aes = ggplot2::aes(
                                   colour = "blue", fill = "grey60", size = .5,
                                   linetype = 1, weight = 1, alpha = 1, level = NA
                                 ),
                                 handle_na = function(self, data, params) {
                                   # TODO, add smart NA handler.
                                   data
                                 },
                                 
                                 draw_key = function(data, params, size) { 
                                   lwd <- min(data$size, min(size) / 4)
                                   
                                   # Calculate and set colour 
                                   linecol <- blendHex(data$col, "gray30", 1) 
                                   fillcol <- blendHex(data$col, "#BBBBBB", 0.7) 
                                   
                                   grid::grobTree( 
                                     grid::rectGrob( 
                                       width = grid::unit(1, "npc") - grid::unit(lwd, "mm"), 
                                       height = grid::unit(1, "npc") - grid::unit(lwd, "mm"), 
                                       gp = grid::gpar( 
                                         col = fillcol, 
                                         fill = scales::alpha(fillcol, data$alpha), 
                                         lty = data$linetype, 
                                         lwd = lwd * ggplot2::.pt, 
                                         linejoin = "mitre" 
                                       ) 
                                     ), 
                                     grid::linesGrob( 
                                       x = c(0, 0.4, 0.6, 1), 
                                       y = c(0.2, 0.6, 0.4, 0.9), 
                                       gp = grid::gpar( 
                                         col = linecol, 
                                         fill = scales::alpha(linecol, data$alpha), 
                                         lty = data$linetype, 
                                         lwd = lwd * ggplot2::.pt, 
                                         linejoin = "mitre" 
                                       ) 
                                     ) 
                                   ) 
                                 }, 
                                 
                                 draw_panel = function(data, panel_scales, coord) {
                                   line_data <- data %>% filter(data$level %in% first(data$level))
                                   # Intervals have been provided
                                   if(any(!is.na(data[["level"]]))){
                                     # Calculate colour
                                     data$fillcol <- blendHex(data$colour, data$level, 0.7)
                                     # Compute alpha transparency
                                     data$alpha <- grDevices::col2rgb(data$fillcol, alpha = TRUE)[4, ] / 255 * data$alpha
                                     GrobList <- lapply(
                                       split(data, data$fillcol),
                                       function(x){
                                         # Select appropriate Geom and set defaults
                                         if (NROW(x) == 1) { # Linerange
                                           GeomForecastIntervalGeom <- ggplot2::GeomLinerange$draw_panel
                                           x <- transform(x, colour = fillcol, fill = NA, size = size*2)
                                         }
                                         else { # Ribbon
                                           GeomForecastIntervalGeom <- ggplot2::GeomRibbon$draw_group
                                           x <- transform(x, colour = NA, fill = fillcol)
                                         }
                                         return(list(
                                           grob = GeomForecastIntervalGeom(x, panel_scales, coord),
                                           range = mean(x[,"ymax"] - x[,"ymin"], na.rm=TRUE)
                                         )) ## Create list pair with average ymin/ymax to order layers
                                       }
                                     )
                                     # Sort GrobList
                                     GrobList <- lapply(GrobList, function(x) x[["grob"]])[order(vapply(GrobList, FUN=function(x) x[["range"]], FUN.VALUE=numeric(1)), decreasing = TRUE)]
                                   }
                                   else{
                                     GrobList <- list()
                                   }
                                   if(NROW(line_data) > 0){
                                     # Calculate colour
                                     line_data$colour <- blendHex(line_data$colour, "gray30", 1)
                                     if (NROW(line_data) == 1) { # Point
                                       GeomForecastPointGeom <- ggplot2::GeomPoint$draw_panel
                                       pointpred <- transform(line_data, fill = NA, size = size*2)
                                     }
                                     else { # Line
                                       GeomForecastPointGeom <- ggplot2::GeomLine$draw_panel
                                       pointpred <- transform(line_data, fill = NA)
                                     }
                                     GrobList <- append(GrobList, list(GeomForecastPointGeom(pointpred, panel_scales, coord)))
                                   }
                                   ggplot2:::ggname("geom_forecast", do.call(grid::grobTree, GrobList))
                                 }
)

globalVariables("y")
#' Forecast plot
#'
#' Generates forecasts from \code{forecast.ts} and adds them to the plot.
#' Forecasts can be modified via sending forecast specific arguments above.
#'
#' Multivariate forecasting is supported by having each time series on a
#' different group.
#'
#' You can also pass \code{geom_forecast} a \code{forecast} object to add it to
#' the plot.
#'
#' The aesthetics required for the forecasting to work includes forecast
#' observations on the y axis, and the \code{time} of the observations on the x
#' axis. Refer to the examples below. To automatically set up aesthetics, use
#' \code{autoplot}.
#'
#' @param mapping Set of aesthetic mappings created by \code{\link{aes}} or
#' \code{\link{aes_}}. If specified and \code{inherit.aes = TRUE} (the
#' default), it is combined with the default mapping at the top level of the
#' plot. You must supply \code{mapping} if there is no plot mapping.
#' @param data The data to be displayed in this layer. There are three options:
#'
#' If \code{NULL}, the default, the data is inherited from the plot data as
#' specified in the call to \code{\link{ggplot}}.
#'
#' A \code{data.frame}, or other object, will override the plot data. All
#' objects will be fortified to produce a data frame. See \code{\link{fortify}}
#' for which variables will be created.
#'
#' A \code{function} will be called with a single argument, the plot data. The
#' return value must be a \code{data.frame}, and will be used as the layer
#' data.
#' @param stat The stat object to use calculate the data.
#' @param position Position adjustment, either as a string, or the result of a
#' call to a position adjustment function.
#' @param na.rm If \code{FALSE} (the default), removes missing values with a
#' warning.  If \code{TRUE} silently removes missing values.
#' @param show.legend logical. Should this layer be included in the legends?
#' \code{NA}, the default, includes if any aesthetics are mapped. \code{FALSE}
#' never includes, and \code{TRUE} always includes.
#' @param inherit.aes If \code{FALSE}, overrides the default aesthetics, rather
#' than combining with them. This is most useful for helper functions that
#' define both data and aesthetics and shouldn't inherit behaviour from the
#' default plot specification, e.g. \code{\link{borders}}.
#' @param level A vector of numbers between 0 and 100 which define the confidence 
#' range to be plotted. If \code{NULL}, confidence intervals will not be plotted, 
#' giving only the forecast line.
#' @param showgap If \code{showgap=FALSE}, the gap between the historical
#' observations and the forecasts is removed.
#' @param model The time-series model used to produce the forecast. The data
#' must be \code{y} (indicating aesthetic \code{y}), and the time index for \code{y} is determined from the
#' \code{x} aesthetic.
#' @param fc.args A list of arguments to be used in the \code{\link{forecast}} function
#' @param ... Additional arguments for \code{\link{forecast.ts}}, other
#' arguments are passed on to \code{\link{layer}}. These are often aesthetics,
#' used to set an aesthetic to a fixed value, like \code{color = "red"} or
#' \code{alpha = .5}. They may also be parameters to the paired geom/stat.
#' @return A layer for a ggplot graph.
#' @author Mitchell O'Hara-Wild
#' @seealso \code{\link{forecast}}, \code{\link[ggplot2]{ggproto}}
#' @examples
#'
#' \dontrun{
#' library(ggplot2)
#' library(tidyr)
#' library(tsibbledata)
#' UKLungDeaths %>%
#'  gather(Gender, Deaths, -index) %>%
#'  autoplot() + 
#'  geom_forecast()
#' }
#'
#' @export
geom_forecast <- function(mapping = NULL, data = NULL, stat = "forecast",
                          position = "identity", na.rm = FALSE, show.legend = NA,
                          inherit.aes = TRUE, level=c(80, 95), showgap=TRUE, 
                          model = ETS(y), fc.args = list(), ...) {
  # if (is_tsibble(mapping)) {
  #   data <- data.frame(y = as.numeric(mapping), x = as.numeric(time(mapping)))
  #   mapping <- ggplot2::aes_(y = ~y, x = ~x)
  # }
  if (stat == "forecast") {
    paramlist <- list(na.rm = na.rm, showgap = showgap, levels = level,
                      model = enexpr(model), fc.args = fc.args, ...)
    if (!inherits(mapping, "uneval")) {
      mapping <- ggplot2::aes_()
    }
    if (!is.null(level)) {
      mapping$level <- quote(..level..)
    }
  }
  else {
    paramlist <- list(na.rm = na.rm, ...)
  }
  ggplot2::layer(
    geom = GeomForecast, mapping = mapping,  data = data, stat = stat, 
    position = position, show.legend = show.legend, inherit.aes = inherit.aes,
    params = paramlist
  )
}