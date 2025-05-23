## This file is part of SimInf, a framework for stochastic
## disease spread simulations.
##
## Copyright (C) 2015 Pavol Bauer
## Copyright (C) 2017 -- 2019 Robin Eriksson
## Copyright (C) 2015 -- 2019 Stefan Engblom
## Copyright (C) 2015 -- 2025 Stefan Widgren
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

valid_events <- function(object) {
    if (!all(object@time > 0))
        return("time must be greater than 0.")

    if (any(object@event < 0, object@event > 3))
        return("event must be in the range 0 <= event <= 3.")

    if (any(object@node < 1))
        return("'node' must be greater or equal to 1.")

    if (any(object@dest[object@event == 3] < 1))
        return("'dest' must be greater or equal to 1.")

    if (any(object@proportion < 0, object@proportion > 1))
        return("prop must be in the range 0 <= prop <= 1.")

    if (any(object@select < 1, object@select > dim(object@E)[2]))
        return("select must be in the range 1 <= select <= Nselect.")

    if (any(object@shift[object@event == 2] < 1))
        return("'shift' must be greater or equal to 1.")

    character(0)
}

## Check if the SimInf_events object is valid.
valid_SimInf_events_object <- function(object) {
    ## Check that E and N have identical compartments
    if ((dim(object@E)[1] > 0) && (dim(object@N)[1] > 0)) {
        if (any(is.null(rownames(object@E)), is.null(rownames(object@N))))
            return("'E' and 'N' must have rownames matching the compartments.")
        if (!identical(rownames(object@E), rownames(object@N)))
            return("'E' and 'N' must have identical compartments.")
    }

    if (any(object@E < 0))
        return("Select matrix 'E' has negative elements.")

    if (!identical(length(unique(c(length(object@event),
                                   length(object@time),
                                   length(object@node),
                                   length(object@dest),
                                   length(object@n),
                                   length(object@proportion),
                                   length(object@select),
                                   length(object@shift)))), 1L)) {
        return("All scheduled events must have equal length.")
    }

    errors <- valid_events(object)
    if (length(errors))
        return(errors)

    TRUE
}

## Assign the function as the validity method for the class.
setValidity("SimInf_events", valid_SimInf_events_object)

init_E <- function(E, events) {
    if (is.null(E)) {
        if (!is.null(events))
            stop("events is not NULL when E is NULL.", call. = FALSE)
        E <- methods::new("dgCMatrix")
    } else {
        E <- init_sparse_matrix(E)
    }

    E
}

init_events <- function(events, t0) {
    if (is.null(events)) {
        events <- data.frame(event      = as.integer(),
                             time       = as.integer(),
                             node       = as.integer(),
                             dest       = as.integer(),
                             n          = as.integer(),
                             proportion = as.numeric(),
                             select     = as.integer(),
                             shift      = as.integer())
    }
    if (!is.data.frame(events))
        stop("events must be a data.frame.", call. = FALSE)
    if (!all(c("event", "time", "node", "dest",
               "n", "proportion", "select",
               "shift") %in% names(events))) {
        stop("Missing columns in events.", call. = FALSE)
    }

    ## Do we have to recode the event type as a numerical value
    if (any(is.character(events$event), is.factor(events$event))) {
        event_names <- c("enter", "exit", "extTrans", "intTrans")
        if (!all(events$event %in% event_names)) {
            stop(paste0("'event' type must be 'enter', 'exit', ",
                        "'extTrans' or 'intTrans'."),
                 call. = FALSE)
        }

        ## Find indices to 'enter', 'internal transfer' and 'external
        ## transfer' events.
        i_enter <- which(events$event == "enter")
        i_intTrans <- which(events$event == "intTrans")
        i_extTrans <- which(events$event == "extTrans")

        ## Replace the character event type with a numerical value.
        events$event <- rep(0L, nrow(events))
        events$event[i_enter] <- 1L
        events$event[i_intTrans] <- 2L
        events$event[i_extTrans] <- 3L
        attr(events$event, "origin") <- "character"
    }

    ## Check time
    if (nrow(events)) {
        if (methods::is(events$time, "Date")) {
            if (is.null(t0))
                stop("Missing 't0'.", call. = FALSE)
            if (!all(identical(length(t0), 1L), is.numeric(t0)))
                stop("Invalid 't0'.", call. = FALSE)
            t1 <- min(events$time)
            origin <- as.character(t1 - (as.numeric(t1) - t0))
            events$time <- as.numeric(events$time) - t0
            attr(events$time, "origin") <- origin
        } else if (!is.null(t0)) {
            stop("Invalid 't0'.", call. = FALSE)
        }
    }

    events
}

##' Create a \code{\linkS4class{SimInf_events}} object
##'
##' The argument events must be a \code{data.frame} with the following
##' columns:
##' \describe{
##'   \item{event}{
##'     Four event types are supported by the current solvers:
##'     \emph{exit}, \emph{enter}, \emph{internal transfer}, and
##'     \emph{external transfer}.  When assigning the events, they can
##'     either be coded as a numerical value or a character string:
##'     \emph{exit;} \code{0} or \code{'exit'}, \emph{enter;} \code{1}
##'     or \code{'enter'}, \emph{internal transfer;} \code{2} or
##'     \code{'intTrans'}, and \emph{external transfer;} \code{3} or
##'     \code{'extTrans'}.  Internally in \pkg{SimInf}, the event type
##'     is coded as a numerical value.
##'   }
##'   \item{time}{
##'     When the event occurs i.e., the event is processed when time
##'     is reached in the simulation. Can be either an \code{integer}
##'     or a \code{Date} vector.  A \code{Date} vector is coerced to a
##'     numeric vector as days, where \code{t0} determines the offset
##'     to match the time of the events to the model \code{tspan}
##'     vector.
##'   }
##'   \item{node}{
##'     The node that the event operates on. Also the source node for
##'     an \emph{external transfer} event.
##'     1 <= \code{node[i]} <= Number of nodes.
##'   }
##'   \item{dest}{
##'     The destination node for an \emph{external transfer} event
##'     i.e., individuals are moved from \code{node} to \code{dest},
##'     where 1 <= \code{dest[i]} <= Number of nodes.  Set \code{event
##'     = 0} for the other event types.  \code{dest} is an integer
##'     vector.
##'   }
##'   \item{n}{
##'     The number of individuals affected by the event. n[i] >= 0.
##'   }
##'   \item{proportion}{
##'     If \code{n[i]} equals zero, the number of individuals affected
##'     by \code{event[i]} is calculated by sampling the number of
##'     individuals from a binomial distribution using the
##'     \code{proportion[i]} and the number of individuals in the
##'     compartments. Numeric vector.  0 <= proportion[i] <= 1.
##'   }
##'   \item{select}{
##'     To process an \code{event[i]}, the compartments affected by
##'     the event are specified with \code{select[i]} together with
##'     the matrix \code{E}, where \code{select[i]} determines which
##'     column in \code{E} to use.  The specific individuals affected
##'     by the event are sampled from the compartments corresponding
##'     to the non-zero entries in the specified column in \code{E[,
##'     select[i]]}, where \code{select} is an integer vector.
##'   }
##'   \item{shift}{
##'     Determines how individuals in \emph{internal transfer} and
##'     \emph{external transfer} events are shifted to enter another
##'     compartment.  The sampled individuals are shifted according to
##'     column \code{shift[i]} in matrix \code{N} i.e., \code{N[,
##'     shift[i]]}, where \code{shift} is an integer vector.  See
##'     above for a description of \code{N}. Unsued for the other
##'     event types.
##'   }
##' }
##'
##' @param E Each row corresponds to one compartment in the model. The
##'     non-zero entries in a column indicates the compartments to
##'     include in an event.  For the \emph{exit}, \emph{internal
##'     transfer} and \emph{external transfer} events, a non-zero
##'     entry indicate the compartments to sample individuals from.
##'     For the \emph{enter} event, all individuals enter first
##'     non-zero compartment. \code{E} is sparse matrix of class
##'     \code{\link[Matrix:dgCMatrix-class]{dgCMatrix}}.
##' @param N Determines how individuals in \emph{internal transfer}
##'     and \emph{external transfer} events are shifted to enter
##'     another compartment.  Each row corresponds to one compartment
##'     in the model.  The values in a column are added to the current
##'     compartment of sampled individuals to specify the destination
##'     compartment, for example, a value of \code{1} in an entry
##'     means that sampled individuals in this compartment are moved
##'     to the next compartment.  Which column to use for each event
##'     is specified by the \code{shift} vector (see below).  \code{N}
##'     is an integer matrix.
##' @param events A \code{data.frame} with events.
##' @param t0 If \code{events$time} is a \code{Date} vector, then
##'     \code{t0} determines the offset to match the time of the
##'     events to the model \code{tspan} vector, see details. If
##'     \code{events$time} is a numeric vector, then \code{t0} must be
##'     \code{NULL}.
##' @return S4 class \code{SimInf_events}
##' @include check_arguments.R
##' @export
##' @examples
##' ## Let us illustrate how movement events can be used to transfer
##' ## individuals from one node to another.  Use the built-in SIR
##' ## model and start with 2 nodes where all individuals are in the
##' ## first node (100 per compartment).
##' u0 <- data.frame(S = c(100, 0), I = c(100, 0), R = c(100, 0))
##'
##' ## Then create 300 movement events to transfer all individuals,
##' ## one per day, from the first node to the second node. Use the
##' ## fourth column in the select matrix where all compartments
##' ## can be sampled with equal weight.
##' events <- data.frame(event      = rep("extTrans", 300),
##'                      time       = 1:300,
##'                      node       = 1,
##'                      dest       = 2,
##'                      n          = 1,
##'                      proportion = 0,
##'                      select     = 4,
##'                      shift      = 0)
##'
##' ## Create an SIR model without disease transmission to
##' ## demonstrate the events.
##' model <- SIR(u0      = u0,
##'              tspan  = 1:300,
##'              events = events,
##'              beta   = 0,
##'              gamma  = 0)
##'
##' ## Run the model and plot the number of individuals in
##' ## the second node.  As can be seen in the figure, all
##' ## indivuduals have been moved to the second node when
##' ## t = 300.
##' plot(run(model), index = 1:2, range = FALSE)
##'
##' ## Let us now double the weight to sample from the 'I'
##' ## compartment and rerun the model.
##' model@events@E[2, 4] <- 2
##' plot(run(model), index = 1:2, range = FALSE)
##'
##' ## And much larger weight to sample from the I compartment.
##' model@events@E[2, 4] <- 10
##' plot(run(model), index = 1:2, range = FALSE)
##'
##' ## Increase the weight for the R compartment.
##' model@events@E[3, 4] <- 4
##' plot(run(model), index = 1:2, range = FALSE)
SimInf_events <- function(E      = NULL,
                          N      = NULL,
                          events = NULL,
                          t0     = NULL) {
    E <- init_E(E, events)
    N <- check_N(N)
    events <- init_events(events, t0)

    if (!all(is.numeric(events$event), is.numeric(events$time),
             is.numeric(events$node), is.numeric(events$dest),
             is.numeric(events$n), is.numeric(events$proportion),
             is.numeric(events$select))) {
        stop("Columns in events must be numeric.", call. = FALSE)
    }

    if (nrow(events)) {
        if (any(!all(is_wholenumber(events$event)),
                !all(is_wholenumber(events$time)),
                !all(is_wholenumber(events$node)),
                !all(is_wholenumber(events$dest)),
                !all(is_wholenumber(events$n)),
                !all(is_wholenumber(events$select)),
                !all(is_wholenumber(events$shift)))) {
            stop("Columns in events must be integer.", call. = FALSE)
        }
    }

    event_origin <- attr(events$event, "origin")
    events$event <- as.integer(events$event)
    time_origin <- attr(events$time, "origin")
    events$time <- as.integer(events$time)
    events <- events[order(events$time, events$event, events$select), ]
    attr(events$event, "origin") <- event_origin
    attr(events$time, "origin") <- time_origin

    methods::new("SimInf_events",
                 E          = E,
                 N          = N,
                 event      = events$event,
                 time       = events$time,
                 node       = as.integer(events$node),
                 dest       = as.integer(events$dest),
                 n          = as.integer(events$n),
                 proportion = as.numeric(events$proportion),
                 select     = as.integer(events$select),
                 shift      = as.integer(events$shift))
}

setAs(
    from = "SimInf_events",
    to = "data.frame",
    def = function(from) {
        events <- data.frame(event = from@event,
                             time = from@time,
                             node = from@node,
                             dest = from@dest,
                             n = from@n,
                             proportion = from@proportion,
                             select = from@select,
                             shift = from@shift)

        if (!is.null(attr(from@event, "origin"))) {
            event_names <- c("exit", "enter", "intTrans", "extTrans")
            events$event <- event_names[events$event + 1]
        }

        if (!is.null(attr(from@time, "origin"))) {
            events$time <- as.Date(events$time,
                                   origin = attr(from@time, "origin"))
        }

        events
    }
)

##' Coerce events to a data frame
##'
##' @method as.data.frame SimInf_events
##' @inheritParams base::as.data.frame
##' @export
as.data.frame.SimInf_events <- function(x, ...) {
    methods::as(x, "data.frame")
}

##' Plot scheduled events
##'
##' @param x the time points of the events.
##' @param y the number of events over time.
##' @param events the event type to plot.
##' @template plot-frame-param
##' @param ... additional arguments affecting the plot.
##' @noRd
plot_SimInf_events <- function(x,
                               y,
                               events = c("Exit",
                                          "Enter",
                                          "Internal transfer",
                                          "External transfer"),
                               frame.plot,
                               ...) {
    events <- match.arg(events)
    i <- switch(events,
                "Exit" = "0",
                "Enter" = "1",
                "Internal transfer" = "2",
                "External transfer" = "3")

    if (length(x)) {
        ylim <- c(0, max(y))

        if (i %in% rownames(y)) {
            y <- y[i, ]
        } else {
            y <- rep(0, length(x))
        }

        graphics::plot(x, y, type = "l", ylim = ylim, xlab = "",
                       ylab = "", frame.plot = frame.plot, ...)
    } else {
        graphics::plot(0, 0, type = "n", xlab = "", ylab = "",
                       frame.plot = frame.plot, ...)
    }

    graphics::mtext(events, side = 3, line = 0)
    graphics::mtext("Individuals", side = 2, line = 2)
    graphics::mtext("Time", side = 1, line = 2)
}

##' Display the distribution of scheduled events over time
##'
##' @param x The events data to plot.
##' @param frame.plot Draw a frame around each plot. Default is FALSE.
##' @param ... Additional arguments affecting the plot
##' @aliases plot,SimInf_events-method
##' @export
setMethod(
    "plot",
    signature(x = "SimInf_events"),
    function(x, frame.plot = FALSE, ...) {
        savepar <- graphics::par(mfrow = c(2, 2),
                                 oma = c(1, 1, 2, 0),
                                 mar = c(4, 3, 1, 1))
        on.exit(graphics::par(savepar))

        yy <- stats::xtabs(n ~ event + time,
                           cbind(event = x@event, time = x@time, n = x@n))
        xx <- as.integer(colnames(yy))
        if (!is.null(attr(x@time, "origin")))
            xx <- as.Date(xx, origin = attr(x@time, "origin"))

        ## Plot events
        plot_SimInf_events(xx, yy, "Exit", frame.plot, ...)
        plot_SimInf_events(xx, yy, "Enter", frame.plot, ...)
        plot_SimInf_events(xx, yy, "Internal transfer", frame.plot, ...)
        plot_SimInf_events(xx, yy, "External transfer", frame.plot, ...)
    }
)

##' Brief summary of \code{SimInf_events}
##'
##' Shows the number of scheduled events.
##' @param object The SimInf_events \code{object}
##' @return None (invisible 'NULL').
##' @export
setMethod(
    "show",
    signature(object = "SimInf_events"),
    function(object) {
        cat(sprintf("Number of scheduled events: %i\n",
                    length(object@event)))
        invisible(object)
    }
)

##' Detailed summary of a \code{SimInf_events} object
##'
##' Shows the number of scheduled events and the number of scheduled
##' events per event type.
##' @param object The \code{SimInf_events} object
##' @param ... Additional arguments affecting the summary produced.
##' @return None (invisible 'NULL').
##' @export
setMethod(
    "summary",
    signature(object = "SimInf_events"),
    function(object, ...) {
        cat(sprintf("Number of scheduled events: %i\n",
                    length(object@event)))

        for (i in seq_len(4)) {
            switch(i,
                   cat(" - Exit: "),
                   cat(" - Enter: "),
                   cat(" - Internal transfer: "),
                   cat(" - External transfer: "))

            j <- which(object@event == (i - 1))
            if (length(j) > 0) {
                cat(sprintf("%i (n: min = %i max = %i avg = %.1f)\n",
                            length(j),
                            min(object@n[j]),
                            max(object@n[j]),
                            mean(object@n[j])))
            } else {
                cat("0\n")
            }
        }
    }
)

##' Extract the events from a \code{SimInf_model} object
##'
##' Extract the scheduled events from a \code{SimInf_model} object.
##' @param object The \code{model} to extract the events from.
##' @param ... Additional arguments affecting the generated events.
##' @return \code{\linkS4class{SimInf_events}} object.
##' @export
##' @examples
##' ## Create an SIR model that includes scheduled events.
##' model <- SIR(u0     = u0_SIR(),
##'              tspan  = 1:(4 * 365),
##'              events = events_SIR(),
##'              beta   = 0.16,
##'              gamma  = 0.077)
##'
##' ## Extract the scheduled events from the model and display summary
##' summary(events(model))
##'
##' ## Extract the scheduled events from the model and plot them
##' plot(events(model))
setGeneric(
    "events",
    signature = "object",
    function(object, ...) {
        standardGeneric("events")
    }
)

##' @rdname events
##' @export
setMethod(
    "events",
    signature(object = "SimInf_model"),
    function(object, ...) {
        object@events
    }
)

##' Extract the shift matrix from a \code{SimInf_model} object
##'
##' Utility function to extract the shift matrix \code{events@@N} from
##' a \code{SimInf_model} object, see
##' \code{\linkS4class{SimInf_events}}
##' @param model The \code{model} to extract the shift matrix
##'     \code{events@@N} from.
##' @return A mtrix.
##' @export
##' @examples
##' ## Create an SIR model
##' model <- SIR(u0 = data.frame(S = 99, I = 1, R = 0),
##'              tspan = 1:5, beta = 0.16, gamma = 0.077)
##'
##' ## Extract the shift matrix from the model
##' shift_matrix(model)
setGeneric(
    "shift_matrix",
    signature = "model",
    function(model) {
        standardGeneric("shift_matrix")
    }
)

##' @rdname shift_matrix
##' @export
setMethod(
    "shift_matrix",
    signature(model = "SimInf_model"),
    function(model) {
        model@events@N
    }
)

##' Set the shift matrix for a \code{SimInf_model} object
##'
##' Utility function to set \code{events@@N} in a \code{SimInf_model}
##' object, see \code{\linkS4class{SimInf_events}}
##' @param model The \code{model} to set the shift matrix
##'     \code{events@@N}.
##' @param value A matrix.
##' @return \code{SimInf_model} object
##' @export
##' @examples
##' ## Create an SIR model
##' model <- SIR(u0 = data.frame(S = 99, I = 1, R = 0),
##'              tspan = 1:5, beta = 0.16, gamma = 0.077)
##'
##' ## Set the shift matrix
##' shift_matrix(model) <- matrix(c(2, 1, 0), nrow = 3)
##'
##' ## Extract the shift matrix from the model
##' shift_matrix(model)
setGeneric(
    "shift_matrix<-",
    signature = "model",
    function(model, value) {
        standardGeneric("shift_matrix<-")
    }
)

##' @rdname shift_matrix-set
##' @export
setMethod(
    "shift_matrix<-",
    signature(model = "SimInf_model"),
    function(model, value) {
        model@events@N <- check_N(value)

        if (nrow(model@events@N) > 0 && is.null(rownames(model@events@N)))
            rownames(model@events@N) <- rownames(model@events@E)
        if (ncol(model@events@N)) {
            colnames(model@events@N) <-
                as.character(seq_len(ncol(model@events@N)))
        }
        methods::validObject(model)

        model
    }
)

##' Extract the select matrix from a \code{SimInf_model} object
##'
##' Utility function to extract \code{events@@E} from a
##' \code{SimInf_model} object, see \code{\linkS4class{SimInf_events}}
##' @param model The \code{model} to extract the select matrix
##'     \code{E} from.
##' @return \code{\link[Matrix:dgCMatrix-class]{dgCMatrix}} object.
##' @export
##' @examples
##' ## Create an SIR model
##' model <- SIR(u0 = data.frame(S = 99, I = 1, R = 0),
##'              tspan = 1:5, beta = 0.16, gamma = 0.077)
##'
##' ## Extract the select matrix from the model
##' select_matrix(model)
setGeneric(
    "select_matrix",
    signature = "model",
    function(model) {
        standardGeneric("select_matrix")
    }
)

##' @rdname select_matrix
##' @export
setMethod(
    "select_matrix",
    signature(model = "SimInf_model"),
    function(model) {
        model@events@E
    }
)

##' Set the select matrix for a \code{SimInf_model} object
##'
##' Utility function to set \code{events@@E} in a \code{SimInf_model}
##' object, see \code{\linkS4class{SimInf_events}}
##' @param model The \code{model} to set the select matrix for.
##' @param value A matrix.
##' @export
##' @examples
##' ## Create an SIR model
##' model <- SIR(u0 = data.frame(S = 99, I = 1, R = 0),
##'              tspan = 1:5, beta = 0.16, gamma = 0.077)
##'
##' ## Set the select matrix
##' select_matrix(model) <- matrix(c(1, 0, 0, 1, 1, 1, 0, 0, 1), nrow = 3)
##'
##' ## Extract the select matrix from the model
##' select_matrix(model)
setGeneric(
    "select_matrix<-",
    signature = "model",
    function(model, value) {
        standardGeneric("select_matrix<-")
    }
)

##' @rdname select_matrix-set
##' @export
setMethod(
    "select_matrix<-",
    signature(model = "SimInf_model"),
    function(model, value) {
        value <- init_sparse_matrix(value)

        if (!identical(Nc(model), dim(value)[1])) {
            stop("'value' must have one row for each compartment in the model.",
                 call. = FALSE)
        }

        dimnames(value) <- list(rownames(model@events@E),
                                as.character(seq_len(dim(value)[2])))
        model@events@E <- value

        methods::validObject(model)

        model
    }
)
