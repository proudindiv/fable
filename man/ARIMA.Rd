% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/arima.R
\name{ARIMA}
\alias{ARIMA}
\title{Fit ARIMA model to univariate time series}
\usage{
ARIMA(data, formula, period = "smallest", ...)
}
\arguments{
\item{data}{A data frame}

\item{formula}{Model specification.}

\item{period}{Time series frequency for seasonal component.}

\item{...}{Additional arguments to be passed to \code{\link[stats]{arima}}.}
}
\value{
See the \code{\link[stats]{arima}} function in the stats package.
The additional objects returned are \item{x}{The time series data}
\item{xreg}{The regressors used in fitting (when relevant).}
}
\description{
Largely a wrapper for the \code{\link[stats]{arima}} function in the stats
package. The main difference is that this function allows a drift term. It
is also possible to take an ARIMA model from a previous call to \code{Arima}
and re-apply it to the data \code{y}.
}
\details{
See the \code{\link[stats]{arima}} function in the stats package.
}
\examples{

USAccDeaths \%>\%
  ARIMA(log(value) ~ pdq(0,1,1) + PDQ(0,1,1))

}
\seealso{
\code{\link{auto.arima}}, \code{\link{forecast.Arima}}.
}
