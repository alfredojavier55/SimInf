% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/abc.R
\name{abc}
\alias{abc}
\alias{abc,SimInf_model-method}
\title{Approximate Bayesian computation}
\usage{
abc(
  model,
  priors = NULL,
  n_particles = NULL,
  n_init = NULL,
  distance = NULL,
  tolerance = NULL,
  data = NULL,
  verbose = getOption("verbose", FALSE),
  post_gen = NULL,
  init_model = NULL
)

\S4method{abc}{SimInf_model}(
  model,
  priors = NULL,
  n_particles = NULL,
  n_init = NULL,
  distance = NULL,
  tolerance = NULL,
  data = NULL,
  verbose = getOption("verbose", FALSE),
  post_gen = NULL,
  init_model = NULL
)
}
\arguments{
\item{model}{The \code{SimInf_model} object to generate data from.}

\item{priors}{The priors for the parameters to fit. Each prior is
specified with a formula notation, for example, \code{beta ~
uniform(0, 1)} specifies that beta is uniformly distributed
between 0 and 1. Use \code{c()} to provide more than one
prior, for example, \code{c(beta ~ uniform(0, 1), gamma ~
normal(10, 1))}. The following distributions are supported:
\code{gamma}, \code{lognormal}, \code{normal} and
\code{uniform}. All parameters in \code{priors} must be only
in either \code{gdata} or \code{ldata}.}

\item{n_particles}{An integer \code{(>1)} specifying the number of
particles to approximate the posterior with.}

\item{n_init}{Specify a positive integer (>\code{n_particles}) to
adaptively select a sequence of tolerances using the algorithm
of Simola and others (2021). The initial tolerance is
adaptively selected by sampling \code{n_init} draws from the
prior and then retain the \code{n_particles} particles with
the smallest distances. Note there must be enough initial
particles to satisfactorily explore the parameter space, see
Simola and others (2021). If the \code{tolerance} parameter is
specified, then \code{n_init} must be \code{NULL}.}

\item{distance}{A function for calculating the summary statistics
for a simulated trajectory. For each particle, the function
must determine the distance and return that information. The
first argument, \code{result}, passed to the \code{distance}
function is the result from a \code{run} of the model with one
trajectory attached to it. The second argument,
\code{generation}, to \code{distance} is an integer with the
generation of the particle(s). Further arguments that can
passed to the \code{distance} function comes from \code{...}
in the \code{abc} function. Depending on the underlying model
structure, data for one or more particles have been generated
in each call to \code{distance}. If the \code{model} only
contains one node and all the parameters to fit are in
\code{ldata}, then that node will be replicated and each of
the replicated nodes represent one particle in the trajectory
(see \sQuote{Examples}). On the other hand if the model
contains multiple nodes or the parameters to fit are contained
in \code{gdata}, then the trajectory in the \code{result}
argument represents one particle. The function can return a
numeric matrix (number of particles \eqn{\times} number of
summary statistics). Or, if the distance contains one summary
statistic, a numeric vector with the length equal to the
number of particles. Note that when using adaptive tolerance
selection, only one summary statistic can be used, i.e., the
function must return a matrix (number of particles
\eqn{\times} 1) or a numeric vector.}

\item{tolerance}{A numeric matrix (number of summary statistics
\eqn{\times} number of generations) where each column contains
the tolerances for a generation and each row contains a
sequence of gradually decreasing tolerances. Can also be a
numeric vector if there is only one summary statistic. The
tolerance determines the number of generations of ABC-SMC to
run. If the \code{n_init} parameter is specified, then
\code{tolerance} must be \code{NULL}.}

\item{data}{Optional data to be passed to the \code{distance}
function. Default is \code{NULL}.}

\item{verbose}{prints diagnostic messages when \code{TRUE}. The
default is to retrieve the global option \code{verbose} and
use \code{FALSE} if it is not set.}

\item{post_gen}{An optional function that, if non-NULL, is applied
after each completed generation. The function must accept one
argument of type \code{SimInf_abc} with the current state of
the fitting process. This function can be useful to, for
example, save and inspect intermediate results.}

\item{init_model}{An optional function that, if non-NULL, is
applied before running each proposal. The function must accept
one argument of type \code{SimInf_model} with the current
model of the fitting process. This function can be useful to
specify the initial state of \code{u0} or \code{v0} of the
model before running a trajectory with proposed parameters.}
}
\value{
A \code{SimInf_abc} object.
}
\description{
Approximate Bayesian computation
}
\examples{
\dontrun{
## Let us consider an SIR model in a closed population with N = 100
## individuals of whom one is initially infectious and the rest are
## susceptible. First, generate one realisation (with a specified
## seed) from the model with known parameters \code{beta = 0.16} and
## \code{gamma = 0.077}. Then, use \code{abc} to infer the (known)
## parameters from the simulated data.
model <- SIR(u0 = data.frame(S = 99, I = 1, R = 0),
             tspan = 1:100,
             beta = 0.16,
             gamma = 0.077)

## Run the SIR model and plot the number of infectious.
set.seed(22)
infectious <- trajectory(run(model), "I")$I
plot(infectious, type = "s")

## The distance function to accept or reject a proposal. Each node
## in the simulated trajectory (contained in the 'result' object)
## represents one proposal.
distance <- function(result, ...) {
    ## Extract the time-series of infectious in each node as a
    ## data.frame.
    sim <- trajectory(result, "I")

    ## Split the 'sim' data.frame by node and calculate the sum of the
    ## squared distance at each time-point for each node.
    dist <- tapply(sim$I, sim$node, function(sim_infectious) {
        sum((infectious - sim_infectious)^2)
    })

    ## Return the distance for each node. Each proposal will be
    ## accepted or rejected depending on if the distance is less than
    ## the tolerance for the current generation.
    dist
}

## Fit the model parameters using ABC-SMC and adaptive tolerance
## selection. The priors for the parameters are specified using a
## formula notation. Here we use a uniform distribtion for each
## parameter with lower bound = 0 and upper bound = 1. Note that we
## use a low number particles here to keep the run-time of the example
## short. In practice you would want to use many more to ensure better
## approximations.
fit <- abc(model = model,
           priors = c(beta ~ uniform(0, 1), gamma ~ uniform(0, 1)),
           n_particles = 100,
           n_init = 1000,
           distance = distance,
           verbose = TRUE)

## Print a brief summary.
fit

## Display the ABC posterior distribution.
plot(fit)
}
}
\references{
\Toni2009

\Simola2021
}
\seealso{
\code{\link{continue_abc}}.
}
