% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/loess.R
\name{boot_fit_loess}
\alias{boot_fit_loess}
\title{Fit a LOESS model with bootstrap samples}
\usage{
boot_fit_loess(bullet, groove, B = 1000, alpha = 0.95)
}
\arguments{
\item{bullet}{Bullet as returned from fortify_x3p}

\item{groove}{Groove as returned from get_grooves}

\item{B}{number of Bootstrap samples}

\item{alpha}{The significance level}
}
\description{
Fit a LOESS model with bootstrap samples
}
