## This file is part of SimInf, a framework for stochastic
## disease spread simulations.
##
## Copyright (C) 2015 -- 2024 Stefan Widgren
##
## SimInf is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## SimInf is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.

##' Class \code{"SimInf_abc"}
##'
##' @slot model The \code{SimInf_model} object to estimate parameters
##'     in.
##' @template priors-slot
##' @slot target Character vector (\code{gdata} or \code{ldata}) that
##'     determines if the ABC-SMC method estimates parameters in
##'     \code{model@@gdata} or in \code{model@@ldata}.
##' @slot pars Index to the parameters in \code{target}.
##' @slot nprop An integer vector with the number of simulated
##'     proposals in each generation.
##' @slot fn A function for calculating the summary statistics for the
##'     simulated trajectory and determine the distance for each
##'     particle, see \code{\link{abc}} for more details.
##' @slot tolerance A numeric matrix (number of summary statistics
##'     \eqn{\times} number of generations) where each column contains
##'     the tolerances for a generation and each row contains a
##'     sequence of gradually decreasing tolerances.
##' @slot x A numeric array (number of particles \eqn{\times} number
##'     of parameters \eqn{\times} number of generations) with the
##'     parameter values for the accepted particles in each
##'     generation. Each row is one particle.
##' @slot weight A numeric matrix (number of particles \eqn{\times}
##'     number of generations) with the weights for the particles
##'     \code{x} in the corresponding generation.
##' @slot distance A numeric array (number of particles \eqn{\times}
##'     number of summary statistics \eqn{\times} number of
##'     generations) with the distance for the particles \code{x} in
##'     each generation. Each row contains the distance for a particle
##'     and each column contains the distance for a summary statistic.
##' @slot ess A numeric vector with the effective sample size (ESS) in
##'     each generation. The effective sample size is computed as
##'     \deqn{\left(\sum_{i=1}^N\!(w_{g}^{(i)})^2\right)^{-1},}{1 /
##'     (sum(w_ig^2)),} where \eqn{w_{g}^{(i)}}{w_ig} is the
##'     normalized weight of particle \eqn{i} in generation \eqn{g}.
##' @slot init_model An optional function that, if non-NULL, is
##'     applied before running each proposal. The function must accept
##'     one argument of type \code{SimInf_model} with the current
##'     model of the fitting process. This function can be useful to
##'     specify the initial state of \code{u0} or \code{v0} of the
##'     model before running a trajectory with proposed parameters.
##' @seealso \code{\link{abc}} and \code{\link{continue_abc}}.
##' @export
setClass(
    "SimInf_abc",
    slots = c(model      = "SimInf_model",
              priors     = "data.frame",
              target     = "character",
              pars       = "integer",
              nprop      = "integer",
              fn         = "function",
              tolerance  = "matrix",
              x          = "array",
              weight     = "matrix",
              distance   = "array",
              ess        = "numeric",
              init_model = "ANY")
)

##' Check if a SimInf_abc object is valid
##'
##' @param object The SimInf_abc object to check.
##' @noRd
valid_SimInf_abc_object <- function(object) {
    ## Check model
    validObject(object@model)

    if (!identical(storage.mode(object@x), "double"))
        return("The storage mode of 'x' must be double.")

    if (!identical(storage.mode(object@distance), "double"))
        return("The storage mode of 'distance' must be double.")

    if (!identical(storage.mode(object@tolerance), "double"))
        return("The storage mode of 'tolerance' must be double.")

    if (!identical(storage.mode(object@weight), "double"))
        return("The storage mode of 'weight' must be double.")

    if (all(!is.null(object@init_model),
            !is.function(object@init_model))) {
        return("'init_model' must be 'NULL' or a 'function'.")
    }

    TRUE
}

## Assign the function as the validity method for the class.
setValidity("SimInf_abc", valid_SimInf_abc_object)

setAs(
    from = "SimInf_abc",
    to = "data.frame",
    def = function(from) {
        do.call("rbind", lapply(seq_len(n_generations(from)), function(i) {
            cbind(generation = i,
                  weight = from@weight[, i],
                  as.data.frame(abc_particles(from, i)))
        }))
    }
)

##' Coerce to data frame
##'
##' @method as.data.frame SimInf_abc
##'
##' @inheritParams base::as.data.frame
##' @export
as.data.frame.SimInf_abc <- function(x, ...) {
    methods::as(x, "data.frame")
}

##' Determine the number of generations
##'
##' @param object the \code{SimInf_abc} object to determine the number
##'     of generations for.
##' @return an integer with the number of generations.
##' @export
setGeneric(
    "n_generations",
    signature = "object",
    function(object) {
        standardGeneric("n_generations")
    }
)

##' @rdname n_generations
##' @export
setMethod(
    "n_generations",
    signature(object = "SimInf_abc"),
    function(object) {
        dim(object@x)[3]
    }
)

summary_particles <- function(object, i) {
    str <- sprintf("Generation %i:", i)
    cat(sprintf("\n%s\n", str))
    cat(sprintf("%s\n", paste0(rep("-", nchar(str)), collapse = "")))
    cat(sprintf(" Accrate: %.2e\n", abc_n_particles(object) / object@nprop[i]))
    cat(sprintf(" ESS: %.2e\n\n", object@ess[i]))
    summary_matrix(t(abc_particles(object, i)))
}

##' Print summary of a \code{SimInf_abc} object
##'
##' @param object The \code{SimInf_abc} object.
##' @return \code{invisible(object)}.
##' @export
setMethod(
    "show",
    signature(object = "SimInf_abc"),
    function(object) {
        cat(sprintf("Number of particles per generation: %i\n",
                    abc_n_particles(object)))
        cat(sprintf("Number of generations: %i\n",
                    n_generations(object)))

        if (n_generations(object))
            summary_particles(object, n_generations(object))

        invisible(object)
    }
)

##' Detailed summary of a \code{SimInf_abc} object
##'
##' @param object The \code{SimInf_abc} object
##' @param ... Additional arguments affecting the summary produced.
##' @return None (invisible 'NULL').
##' @include SimInf_model.R
##' @export
setMethod(
    "summary",
    signature(object = "SimInf_abc"),
    function(object, ...) {
        cat(sprintf("Number of particles per generation: %i\n",
                    abc_n_particles(object)))
        cat(sprintf("Number of generations: %i\n",
                    n_generations(object)))

        for (i in seq_len(n_generations(object))) {
            summary_particles(object, i)
        }

        invisible(NULL)
    }
)

##' Determine the number of particles.
##' @noRd
abc_n_particles <- function(object) {
    nrow(object@weight)
}

##' Get the particles for a specific generation
##' @noRd
abc_particles <- function(object, generation) {
    stopifnot(is.integer(generation),
              length(generation) ==  1,
              generation[1] >= 1,
              generation[1] <= n_generations(object))

    matrix(as.vector(object@x[, , generation]),
           nrow = abc_n_particles(object),
           dimnames = list(NULL, colnames(object@x)))
}

##' Generate replicates of the first node in the model.
##'
##' Replicate the node specific matrices 'u0', 'v0' and 'ldata' in the
##' first node. Additionally, replicate any events.
##' @param model the model to replicate.
##' @param n the number of replicates.
##' @param n_events the number of events for the first node in the
##'     model.
##' @return A modified model object
##' @noRd
replicate_first_node <- function(model, n, n_events) {
    if (dim(model@u0)[1] > 0)
        model@u0 <- model@u0[, rep(1, n), drop = FALSE]
    if (dim(model@v0)[1] > 0)
        model@v0 <- model@v0[, rep(1, n), drop = FALSE]
    if (dim(model@ldata)[1] > 0)
        model@ldata <- model@ldata[, rep(1, n), drop = FALSE]

    if (n_events > 0) {
        ## Replicate the events in the first node and add an offset to
        ## the node vector. The offset is not added to 'dest' since
        ## there are no external transfer events.
        i <- seq_len(n_events)
        offset <- rep(seq_len(n) - 1L, each = n_events)
        model@events@event <- rep(model@events@event[i], n)
        model@events@time <- rep(model@events@time[i], n)
        model@events@node <- rep(model@events@node[i], n) + offset
        model@events@dest <- rep(model@events@dest[i], n)
        model@events@n <- rep(model@events@n[i], n)
        model@events@proportion <- rep(model@events@proportion[i], n)
        model@events@select <- rep(model@events@select[i], n)
        model@events@shift <- rep(model@events@shift[i], n)
    }

    model
}

abc_proposal_covariance <- function(x) {
    if (is.null(x))
        return(NULL)
    2 * stats::cov(x)
}

abc_init_generation <- function(object) {
    n_generations(object) + 1L
}

abc_init_n_particles <- function(object, n_init, tolerance) {
    if (n_generations(object) > 0 || is.null(n_init))
        return(abc_n_particles(object))

    check_integer_arg(n_init)
    n_init <- as.integer(n_init)
    if (length(n_init) != 1L || n_init <= 1L)
        stop("'n_init' must be an integer > 1.", call. = FALSE)
    if (n_init <= abc_n_particles(object))
        stop("'n_init' must be an integer > 'n_particles'.", call. = FALSE)

    if (!is.null(tolerance))
        stop("'tolerance' must be NULL for adaptive distance.", call. = FALSE)

    n_init
}

abc_init_particles <- function(object) {
    if (n_generations(object) > 0)
        return(abc_particles(object, n_generations(object)))
    NULL
}

abc_init_weights <- function(object) {
    if (ncol(object@weight) > 0L)
        return(object@weight[, ncol(object@weight)])
    NULL
}

abc_init_tolerance <- function(tolerance, tolerance_prev) {
    if (is.null(tolerance))
        return(NULL)

    if (!is.numeric(tolerance))
        stop("'tolerance' must have non-negative values.", call. = FALSE)

    if (!is.matrix(tolerance))
        dim(tolerance) <- c(1L, length(tolerance))

    if (is.integer(tolerance))
        storage.mode(tolerance) <- "double"

    if (ncol(tolerance) == 0)
        stop("'tolerance' must have columns.", call. = FALSE)

    if (anyNA(tolerance) || any(tolerance < 0))
        stop("'tolerance' must have non-negative values.", call. = FALSE)

    if (nrow(tolerance_prev) > 0) {
        ## Check that the number of summary statistics is the same as
        ## in previous generations.
        if (nrow(tolerance) != nrow(tolerance_prev))
            stop("Invalid dimension of 'tolerance'.", call. = FALSE)
        tolerance <- cbind(tolerance_prev, tolerance)
    }

    ## Check that tolerance is a decreasing vector for each summary
    ## statistics.
    if (any(apply(tolerance, 1, diff) >= 0))
        stop("'tolerance' must be a decreasing vector.", call. = FALSE)

    tolerance
}

abc_init_epsilon <- function(tolerance, generation) {
    if (is.null(tolerance))
        return(NULL)
    tolerance[, generation]
}

##' Adaptive selection of the first tolerance
##'
##' The first tolerance is adaptively selected by sorting the 'n_init'
##' distances and select the 'n_particles' distance. The first
##' 'n_particles' particles are retained.
##' @param distance a numeric matrix (number of particles \eqn{\times}
##'     number of summary statistics) with the distance for the
##'     particles. Each row contains the distance for a particle and
##'     each column contains the distance for a summary statistic.
##' @param n_particles An integer specifying the number of particles.
##' @return a numeric vector.
##' @references
##'
##' \CisewskiKehe2019
##' @noRd
abc_first_epsilon <- function(distance, n_particles) {
    i <- order(rowSums(distance))
    distance[i[n_particles], ]
}

abc_next_epsilon <- function(x_old, x, distance, tolerance,
                             generation) {
    if (is.null(tolerance))
        return(abc_adaptive_tolerance(x, x_old, distance, generation))
    if (generation <= ncol(tolerance))
        return(tolerance[, generation])
    NULL
}

##' Adaptive Tolerance Selection
##'
##' Adaptive Approximate Baeysian Computation Tolerance Selection
##' using the algorithm of Simola and others (2021).
##'
##' @param xnu a \code{matrix} with the particles in the current
##'     generation.
##' @param xde a \code{matrix} with the particles in the previous
##'     generation.
##' @param distance the distance for the particles in xnu.
##' @param generation a positive integer with the current generation.
##' @return NULL if the stopping rule applies, else a numeric vector
##'     with the tolerance for the next generation.
##' @references
##'
##' \Simola2021
##' @noRd
abc_adaptive_tolerance <- function(xnu, xde, distance, generation) {
    ## Determine the density ratio by using the Kullback-Leibler
    ## importance estimation procedure.
    k <- KLIEP(xnu, xde)

    ## Determine the supremum by using an optimizer. For
    ## one-dimensional problems, use "Brent" else "Nelder-Mead".
    if (ncol(xnu) > 1) {
        method <- "Nelder-Mead"
        lower <- -Inf
        upper <- Inf
    } else {
        method <- "Brent"
        lower <- min(xnu)
        upper <- max(xnu)
    }

    c_t <- stats::optim(par = xnu[1, ],
                        fn = function(x, centers, sigma, weights) {
                            KLIEP_density_ratio(matrix(x, nrow = 1),
                                                centers = centers,
                                                sigma = sigma,
                                                weights = weights)
                        },
                        centers = k$centers,
                        sigma = k$sigma,
                        weights = k$weights,
                        lower = lower,
                        upper = upper,
                        method = method,
                        control = list(fnscale = -1))

    q_t <- 1 / c_t$value

    ## Check if stopping rule applies.
    if (q_t > 0.99 && generation >= 3L)
        return(NULL)

    i <- order(rowSums(distance))
    distance <- distance[i, , drop = FALSE]
    distance[ceiling(q_t * nrow(distance)), ]
}

abc_progress <- function(t0, t1, x, w, d, n_particles, nprop) {
    cat(sprintf("\n\n  accrate = %.2e, ESS = %.2e time = %.2f secs\n",
                n_particles / nprop, 1 / sum(w^2), (t1 - t0)[3]))

    print_title(ifelse(ncol(d) > 1, "Distances", "Distance"))
    colnames(d) <- paste0(seq_len(ncol(d)), ":")
    summary_matrix(t(d))

    print_title(ifelse(ncol(x) > 1, "Parameters", "Parameter"))
    summary_matrix(t(x))
}

##' Check the result from the ABC distance function.
##' @noRd
abc_distance <- function(distance, n) {
    if (!is.numeric(distance)) {
        stop("The result from the ABC distance function must be numeric.",
             call. = FALSE)
    }

    if (!is.matrix(distance))
        dim(distance) <- c(length(distance), 1L)

    if (is.integer(distance))
        storage.mode(distance) <- "double"

    if (!identical(nrow(distance), n)) {
        stop("Invalid dimension of the result from the ABC distance function.",
             call. = FALSE)
    }

    if (anyNA(distance) || any(distance < 0)) {
        stop("The result from the ABC distance function must be non-negative.",
             call. = FALSE)
    }

    distance
}

##' Determine which particles to accept
##'
##' @param distance a numeric matrix (number of particles \eqn{\times}
##'     number of summary statistics) with the distance for the
##'     particles. Each row contains the distance for a particle and
##'     each column contains the distance for a summary statistic.
##' @param tolerance a numeric vector with the tolerance for each
##'     summary statistics.
##' @return a logical vector of length nrow(distance) with TRUE for
##'     the particles to accept, else FALSE.
##' @noRd
abc_accept <- function(distance, tolerance) {
    if (!identical(ncol(distance), length(tolerance))) {
        stop("Mismatch between the number of summary statistics and tolerance.",
             call. = FALSE)
    }

    rowSums(distance <= tolerance) == length(tolerance)
}

abc_gdata <- function(model,
                      pars,
                      priors,
                      n_particles,
                      fn,
                      generation,
                      tolerance,
                      x,
                      w,
                      sigma,
                      verbose,
                      init_model,
                      data) {
    if (isTRUE(verbose))
        pb <- utils::txtProgressBar(min = 0, max = n_particles, style = 3)

    if (!is.null(tolerance)) {
        distance <- matrix(NA_real_,
                           nrow = n_particles,
                           ncol = length(tolerance))
    }
    xx <- matrix(NA_real_, nrow = n_particles, ncol = length(pars),
                 dimnames = list(NULL, names(model@gdata)[pars]))
    ancestor <- rep(NA_real_, n_particles)
    nprop <- 0L
    particle_i <- 0L

    while (particle_i < n_particles) {
        model_proposals <- model
        proposals <- .Call(SimInf_abc_proposals, priors$parameter,
                           priors$distribution, priors$p1, priors$p2,
                           1L, x, w, sigma)
        for (i in seq_len(ncol(proposals))) {
            model_proposals@gdata[pars[i]] <- proposals[1L, i]
        }

        ## Handle the init_model callback.
        if (is.function(init_model))
            model_proposals <- init_model(model_proposals)

        d <- abc_distance(
            fn(run(model_proposals), generation, data), 1L)
        if (is.null(tolerance)) {
            ## Accept all particles if the tolerance is NULL, but make
            ## sure the dimension of tolerance and distance matches in
            ## subsequent calls to 'abc_accept'.
            tolerance <- rep(Inf, ncol(d))
            distance <- matrix(NA_real_, nrow = n_particles, ncol = ncol(d))
            if (!identical(ncol(d), 1L)) {
                stop("Adaptive tolerance must have one summary statistic.",
                     call. = FALSE)
            }
        }

        accept <- abc_accept(d, tolerance)
        nprop <- nprop + 1L
        if (isTRUE(accept)) {
            ## Collect accepted particle
            particle_i <- particle_i + 1L
            distance[particle_i, ] <- d
            xx[particle_i, ] <- model_proposals@gdata[pars]
            ancestor[particle_i] <- attr(proposals, "ancestor")[1L]
        }

        ## Report progress.
        if (isTRUE(verbose))
            utils::setTxtProgressBar(pb, particle_i)
    }

    list(x = xx, ancestor = ancestor, distance = distance, nprop = nprop)
}

abc_ldata <- function(model,
                      pars,
                      priors,
                      n_particles,
                      fn,
                      generation,
                      tolerance,
                      x,
                      w,
                      sigma,
                      verbose,
                      init_model,
                      data) {
    ## Handle the init_model callback.
    if (!is.null(init_model)) {
        stop("'init_model' callback is not implemented for 'ldata'.",
             call. = FALSE)
    }

    ## Let each node represents one particle. Replicate the first node
    ## to run multiple particles simultaneously. Start with 10 x
    ## 'n_particles' and then increase the number adaptively based on
    ## the acceptance rate.
    n <- as.integer(10 * n_particles)
    n_events <- length(model@events@event)
    model <- replicate_first_node(model, n, n_events)

    if (isTRUE(verbose))
        pb <- utils::txtProgressBar(min = 0, max = n_particles, style = 3)

    if (!is.null(tolerance)) {
        distance <- matrix(NA_real_,
                           nrow = n_particles,
                           ncol = length(tolerance))
    }
    xx <- matrix(NA_real_, nrow = n_particles, ncol = length(pars),
                 dimnames = list(NULL, rownames(model@ldata)[pars]))
    ancestor <- rep(NA_real_, n_particles)
    nprop <- 0L
    particle_i <- 0L

    while (particle_i < n_particles) {
        if (all(n < 1e5L, nprop > 2L * n)) {
            ## Increase the number of particles that are simulated in
            ## each trajectory.
            n <- min(1e5L, n * 2L)
            model <- replicate_first_node(model, n, n_events)
        }

        proposals <- .Call(SimInf_abc_proposals, priors$parameter,
                           priors$distribution, priors$p1, priors$p2,
                           n, x, w, sigma)
        for (i in seq_len(ncol(proposals))) {
            model@ldata[pars[i], ] <- proposals[, i]
        }

        d <- abc_distance(fn(run(model), generation, data), n)
        if (is.null(tolerance)) {
            ## Accept all particles if the tolerance is NULL, but make
            ## sure the dimension of tolerance and distance matches in
            ## subsequent calls to 'abc_accept'.
            tolerance <- rep(Inf, ncol(d))
            distance <- matrix(NA_real_, nrow = n_particles, ncol = ncol(d))
            if (!identical(ncol(d), 1L)) {
                stop("Adaptive tolerance must have one summary statistic.",
                     call. = FALSE)
            }
        }

        ## Collect accepted particles making sure not to collect more
        ## than 'n_particles'.
        accept <- abc_accept(d, tolerance)
        i <- cumsum(accept) + particle_i
        i <- which(i == n_particles)
        j <- which(accept)
        if (length(i)) {
            i <- min(i)
            j <- j[j <= i]
            nprop <- nprop + i
        } else {
            nprop <- nprop + n
        }

        if (length(j)) {
            k <- seq(from = particle_i + 1L, length.out = length(j))
            distance[k, ] <- d[j, , drop = FALSE]
            xx[k, ] <- t(model@ldata[pars, j, drop = FALSE])
            ancestor[k] <- attr(proposals, "ancestor")[j]
            particle_i <- particle_i + length(j)
        }

        ## Report progress.
        if (isTRUE(verbose))
            utils::setTxtProgressBar(pb, particle_i)
    }

    list(x = xx, ancestor = ancestor, distance = distance, nprop = nprop)
}

abc_weights <- function(object, generation, x, ancestor, w, sigma) {
    if (!is.null(x))
        x <- x[ancestor, , drop = FALSE]

    .Call(SimInf_abc_weights, object@priors$distribution,
          object@priors$p1, object@priors$p2, x,
          abc_particles(object, generation), w, sigma)
}

abc_internal <- function(object,
                         n_init,
                         tolerance,
                         verbose,
                         post_gen,
                         data) {
    if (!is.null(post_gen))
        post_gen <- match.fun(post_gen)

    if (all(is.null(n_init), is.null(tolerance)))
        stop("Both 'n_init' and 'tolerance' can not be NULL.", call. = FALSE)

    abc_fn <- switch(object@target,
                     "gdata" = abc_gdata,
                     "ldata" = abc_ldata,
                     stop("Unknown target: ", object@target,
                          call. = FALSE))

    generation <- abc_init_generation(object)
    tolerance <- abc_init_tolerance(tolerance, object@tolerance)
    epsilon <- abc_init_epsilon(tolerance, generation)
    n_particles <- abc_init_n_particles(object, n_init, tolerance)
    x <- abc_init_particles(object)
    w <- abc_init_weights(object)

    repeat {
        ## Report progress.
        if (isTRUE(verbose)) {
            cat("\nGeneration", generation, "...\n")
            t0 <- proc.time()
        }

        sigma <- abc_proposal_covariance(x)
        result <- abc_fn(model = object@model,
                         pars = object@pars,
                         priors = object@priors,
                         n_particles = n_particles,
                         fn = object@fn,
                         generation = generation,
                         tolerance = epsilon,
                         x = x,
                         w = w,
                         sigma = sigma,
                         verbose = verbose,
                         init_model = object@init_model,
                         data = data)

        ## Append the tolerance for the generation.
        n_particles <- abc_n_particles(object)
        if (is.null(epsilon))
            epsilon <- abc_first_epsilon(result$distance, n_particles)
        if (ncol(object@tolerance) == 0L)
            dim(object@tolerance) <- c(length(epsilon), 0L)
        object@tolerance <- cbind(object@tolerance, epsilon,
                                  deparse.level = 0)

        if (is.null(tolerance) && generation == 1L) {
            i <- order(rowSums(result$distance))[seq_len(n_particles)]
            result$ancestor <- result$ancestor[i]
            object@x <-
                array(result$x[i, ],
                      dim = c(n_particles, ncol(result$x), generation),
                      dimnames = list(NULL, colnames(result$x), NULL))
            object@distance <-
                array(result$distance[i, , drop = FALSE],
                      dim = c(n_particles, ncol(result$distance), generation))
            x_old <- result$x
        } else {
            object@x <-
                array(c(object@x, result$x),
                      dim = c(n_particles, ncol(result$x), generation),
                      dimnames = list(NULL, colnames(result$x), NULL))
            object@distance <-
                array(c(object@distance, result$distance),
                      dim = c(n_particles, ncol(result$distance), generation))
            x_old <- x
        }

        w <- abc_weights(object, generation, x, result$ancestor, w, sigma)
        object@weight <- cbind(object@weight, w, deparse.level = 0)
        object@ess <- c(object@ess, 1 / sum(w^2))
        object@nprop <- c(object@nprop, result$nprop)
        x <- abc_particles(object, generation)
        d <- matrix(as.vector(object@distance[, , generation]),
                    nrow = abc_n_particles(object))

        ## Report progress.
        if (isTRUE(verbose))
            abc_progress(t0, proc.time(), x, w, d, n_particles, result$nprop)

        ## Handle the post-generation callback.
        if (!is.null(post_gen))
            post_gen(object)

        generation <- generation + 1L
        epsilon <- abc_next_epsilon(x_old, x, d, tolerance, generation)
        if (is.null(epsilon))
            break
    }

    object
}

##' Approximate Bayesian computation
##'
##'
##' @param model The \code{SimInf_model} object to generate data from.
##' @template priors-param
##' @param n_particles An integer \code{(>1)} specifying the number of
##'     particles to approximate the posterior with.
##' @param n_init Specify a positive integer (>\code{n_particles}) to
##'     adaptively select a sequence of tolerances using the algorithm
##'     of Simola and others (2021). The initial tolerance is
##'     adaptively selected by sampling \code{n_init} draws from the
##'     prior and then retain the \code{n_particles} particles with
##'     the smallest distances. Note there must be enough initial
##'     particles to satisfactorily explore the parameter space, see
##'     Simola and others (2021). If the \code{tolerance} parameter is
##'     specified, then \code{n_init} must be \code{NULL}.
##' @param distance A function for calculating the summary statistics
##'     for a simulated trajectory. For each particle, the function
##'     must determine the distance and return that information. The
##'     first argument, \code{result}, passed to the \code{distance}
##'     function is the result from a \code{run} of the model with one
##'     trajectory attached to it. The second argument,
##'     \code{generation}, to \code{distance} is an integer with the
##'     generation of the particle(s). Further arguments that can
##'     passed to the \code{distance} function comes from \code{...}
##'     in the \code{abc} function. Depending on the underlying model
##'     structure, data for one or more particles have been generated
##'     in each call to \code{distance}. If the \code{model} only
##'     contains one node and all the parameters to fit are in
##'     \code{ldata}, then that node will be replicated and each of
##'     the replicated nodes represent one particle in the trajectory
##'     (see \sQuote{Examples}). On the other hand if the model
##'     contains multiple nodes or the parameters to fit are contained
##'     in \code{gdata}, then the trajectory in the \code{result}
##'     argument represents one particle. The function can return a
##'     numeric matrix (number of particles \eqn{\times} number of
##'     summary statistics). Or, if the distance contains one summary
##'     statistic, a numeric vector with the length equal to the
##'     number of particles. Note that when using adaptive tolerance
##'     selection, only one summary statistic can be used, i.e., the
##'     function must return a matrix (number of particles
##'     \eqn{\times} 1) or a numeric vector.
##' @param tolerance A numeric matrix (number of summary statistics
##'     \eqn{\times} number of generations) where each column contains
##'     the tolerances for a generation and each row contains a
##'     sequence of gradually decreasing tolerances. Can also be a
##'     numeric vector if there is only one summary statistic. The
##'     tolerance determines the number of generations of ABC-SMC to
##'     run. If the \code{n_init} parameter is specified, then
##'     \code{tolerance} must be \code{NULL}.
##' @param data Optional data to be passed to the \code{distance}
##'     function. Default is \code{NULL}.
##' @template verbose-param
##' @template post_gen-param
##' @template init_model-param
##' @return A \code{SimInf_abc} object.
##' @references
##'
##' \Toni2009
##'
##' \Simola2021
##' @include density_ratio.R
##' @export
##' @seealso \code{\link{continue_abc}}.
##' @example man/examples/abc.R
setGeneric(
    "abc",
    signature = "model",
    function(model,
             priors = NULL,
             n_particles = NULL,
             n_init = NULL,
             distance = NULL,
             tolerance = NULL,
             data = NULL,
             verbose = getOption("verbose", FALSE),
             post_gen = NULL,
             init_model = NULL) {
        standardGeneric("abc")
    }
)

##' @rdname abc
##' @export
setMethod(
    "abc",
    signature(model = "SimInf_model"),
    function(model,
             priors,
             n_particles,
             n_init,
             distance,
             tolerance,
             data,
             verbose,
             post_gen,
             init_model) {
        n_particles <- check_n_particles(n_particles)
        init_model <- check_init_model(init_model)

        ## Match the 'priors' to parameters in 'ldata' or 'gdata'.
        priors <- parse_priors(priors)
        pars <- match_priors(model, priors)

        object <- methods::new("SimInf_abc",
                               model = model,
                               priors = priors,
                               target = pars$target,
                               pars = pars$pars,
                               nprop = integer(0),
                               fn = match.fun(distance),
                               x = array(numeric(0),
                                         dim = c(0, 0, 0)),
                               tolerance = matrix(numeric(0),
                                                  nrow = 0,
                                                  ncol = 0),
                               weight = matrix(numeric(0),
                                               nrow = n_particles,
                                               ncol = 0),
                               distance = array(numeric(0),
                                                dim = c(0, 0, 0)),
                               ess = numeric(0),
                               init_model = init_model)

        abc_internal(object = object,
                     n_init = n_init,
                     tolerance = tolerance,
                     verbose = verbose,
                     post_gen = post_gen,
                     data = data)
    }
)

##' Run more generations of ABC SMC
##'
##' @param object The \code{SimInf_abc} object to continue from.
##' @param tolerance A numeric matrix (number of summary statistics
##'     \eqn{\times} number of generations) where each column contains
##'     the tolerances for a generation and each row contains a
##'     sequence of gradually decreasing tolerances. Can also be a
##'     numeric vector if there is only one summary statistic. The
##'     tolerance determines the number of generations of ABC-SMC to
##'     run.
##' @param data Optional data to be passed to the
##'     \code{SimInf_abc@@fn} function. Default is \code{NULL}.
##' @template verbose-param
##' @template post_gen-param
##' @return A \code{SimInf_abc} object.
##' @export
setGeneric(
    "continue_abc",
    signature = "object",
    function(object,
             tolerance = NULL,
             data = NULL,
             verbose = getOption("verbose", FALSE),
             post_gen = NULL) {
        standardGeneric("continue_abc")
    }
)

##' @rdname continue_abc
##' @export
setMethod(
    "continue_abc",
    signature(object = "SimInf_abc"),
    function(object,
             tolerance,
             data,
             verbose,
             post_gen) {
        abc_internal(object = object,
                     n_init = NULL,
                     tolerance = tolerance,
                     verbose = verbose,
                     post_gen = post_gen,
                     data = data)
    }
)

##' @rdname run
##' @include run.R
##' @export
setMethod(
    "run",
    signature(model = "SimInf_abc"),
    function(model, ...) {
        ## Sample a particle to use for the parameters from the last
        ## generation.
        generation <- n_generations(model)
        particle <- sample.int(abc_n_particles(model), 1)

        ## Apply the particle to the model.
        for (i in seq_len(dim(model@x)[2])) {
            parameter <- model@pars[i]
            value <- model@x[particle, i, generation]
            if (identical(model@target, "gdata")) {
                model@model@gdata[parameter] <- value
            } else {
                model@model@ldata[parameter, 1] <- value
            }
        }

        ## Run the model using the particle.
        if (is.function(model@init_model))
            return(run(model@init_model(model@model), ...))
        run(model@model, ...)
    }
)
