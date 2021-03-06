#' Perform arbitrary computation on remote backend
#'
#' @inheritParams dplyr::do
#' @param .chunk_size The size of each chunk to pull into R. If this number is
#'   too big, the process will be slow because R has to allocate and free a lot
#'   of memory. If it's too small, it will be slow, because of the overhead of
#'   talking to the database.
#' @export
do.tbl_sql <- function(.data, ..., .chunk_size = 1e4L) {
  groups_sym <- groups(.data)

  if (length(groups_sym) == 0) {
    .data <- collect(.data)
    return(do(.data, ...))
  }

  args <- quos(...)
  named <- named_args(args)

  # Create data frame of labels
  labels <- .data %>%
    select(!!! groups_sym) %>%
    summarise() %>%
    collect()

  con <- .data$src$con

  n <- nrow(labels)
  m <- length(args)

  out <- replicate(m, vector("list", n), simplify = FALSE)
  names(out) <- names(args)
  p <- progress_estimated(n * m, min_time = 2)

  # Create ungrouped data frame suitable for chunked retrieval
  query <- Query$new(con, db_sql_render(con, ungroup(.data)), op_vars(.data))

  # When retrieving in pages, there's no guarantee we'll get a complete group.
  # So we always assume the last group in the chunk is incomplete, and leave
  # it for the next. If the group size is large than chunk size, it may
  # take a couple of iterations to get the entire group, but that should
  # be an unusual situation.
  last_group <- NULL
  i <- 0

  # Assumes `chunk` to be ordered with group columns first
  gvars <- seq_along(groups_sym)

  # Create the dynamic scope for tidy evaluation
  env <- child_env(NULL)
  overscope <- new_overscope(env)
  on.exit(overscope_clean(overscope))

  query$fetch_paged(.chunk_size, function(chunk) {
    if (!is_null(last_group)) {
      chunk <- rbind(last_group, chunk)
    }

    # Create an id for each group
    grouped <- chunk %>% group_by(!!! syms(names(chunk)[gvars]))
    index <- attr(grouped, "indices") # zero indexed
    n <- length(index)

    last_group <<- chunk[index[[length(index)]] + 1L, , drop = FALSE]

    for (j in seq_len(n - 1)) {
      cur_chunk <- chunk[index[[j]] + 1L, , drop = FALSE]
      # Update pronouns within the overscope
      env$. <- env$.data <- cur_chunk
      for (k in seq_len(m)) {
        out[[k]][i + j] <<- list(overscope_eval_next(overscope, args[[k]]))
        p$tick()$print()
      }
    }
    i <<- i + (n - 1)
  })

  # Process last group
  if (!is_null(last_group)) {
    env$. <- env$.data <- last_group
    for (k in seq_len(m)) {
      out[[k]][i + 1] <- list(overscope_eval_next(overscope, args[[k]]))
      p$tick()$print()
    }
  }

  if (!named) {
    label_output_dataframe(labels, out, groups(.data))
  } else {
    label_output_list(labels, out, groups(.data))
  }
}

#' @export
do_.tbl_sql <- function(.data, ..., .dots = list(), .chunk_size = 1e4L) {
  dots <- dplyr:::compat_lazy_dots(.dots, caller_env(), ...)
  do(.data, !!! dots, .chunk_size = .chunk_size)
}


# Helper functions -------------------------------------------------------------

label_output_dataframe <- function(labels, out, groups) {
  data_frame <- vapply(out[[1]], is.data.frame, logical(1))
  if (any(!data_frame)) {
    stop(
      "Results are not data frames at positions: ",
      paste(which(!data_frame), collapse = ", "),
      call. = FALSE
    )
  }

  rows <- vapply(out[[1]], nrow, numeric(1))
  out <- bind_rows(out[[1]])

  if (!is.null(labels)) {
    # Remove any common columns from labels
    labels <- labels[setdiff(names(labels), names(out))]

    # Repeat each row to match data
    labels <- labels[rep(seq_len(nrow(labels)), rows), , drop = FALSE]
    rownames(labels) <- NULL

    grouped_df(bind_cols(labels, out), groups)
  } else {
    rowwise(out)
  }
}

label_output_list <- function(labels, out, groups) {
  if (!is.null(labels)) {
    labels[names(out)] <- out
    rowwise(labels)
  } else {
    class(out) <- "data.frame"
    attr(out, "row.names") <- .set_row_names(length(out[[1]]))
    rowwise(out)
  }
}

named_args <- function(args) {
  # Arguments must either be all named or all unnamed.
  named <- sum(names2(args) != "")
  if (!(named == 0 || named == length(args))) {
    stop(
      "Arguments to do() must either be all named or all unnamed",
      call. = FALSE
    )
  }
  if (named == 0 && length(args) > 1) {
    stop("Can only supply single unnamed argument to do()", call. = FALSE)
  }

  # Check for old syntax
  if (named == 1 && names(args) == ".f") {
    stop(
      "do syntax changed in dplyr 0.2. Please see documentation for details",
      call. = FALSE
    )
  }

  named != 0
}
