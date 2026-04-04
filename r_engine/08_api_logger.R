# =============================================================================
# MODULE 8: API CALL LOGGER
# Logs all Socrata API calls with timestamp, endpoint, rows fetched, status
# Demonstrates pagination handling as required by project spec
# =============================================================================

library(httr)
library(jsonlite)
library(data.table)

log_file <- file.path(dirname(getwd()), "data", "api_call_log.csv")

log_api_call <- function(endpoint, offset, limit, rows_returned, status_code) {
  entry <- data.table(
    timestamp     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    endpoint      = endpoint,
    offset        = offset,
    limit         = limit,
    rows_returned = rows_returned,
    status_code   = status_code
  )
  if (file.exists(log_file)) {
    fwrite(entry, log_file, append = TRUE)
  } else {
    fwrite(entry, log_file)
  }
}

# Example: log a paginated Socrata fetch
fetch_with_logging <- function(base_url, app_token, total_limit = 1000, page_size = 500) {
  all_data <- list()
  offset   <- 0
  page     <- 1

  repeat {
    url <- paste0(base_url,
                  "?$limit=", page_size,
                  "&$offset=", offset,
                  "&$order=:id")

    resp <- GET(url, add_headers("X-App-Token" = app_token))
    rows <- fromJSON(content(resp, "text", encoding = "UTF-8"))

    log_api_call(
      endpoint      = base_url,
      offset        = offset,
      limit         = page_size,
      rows_returned = ifelse(is.data.frame(rows), nrow(rows), 0),
      status_code   = status_code(resp)
    )

    cat(sprintf("Page %d | offset %d | rows: %d | status: %d\n",
                page, offset, ifelse(is.data.frame(rows), nrow(rows), 0), status_code(resp)))

    if (!is.data.frame(rows) || nrow(rows) == 0) break

    all_data[[page]] <- rows
    offset <- offset + page_size
    page   <- page + 1

    if (offset >= total_limit) break
  }

  rbindlist(all_data, fill = TRUE)
}

cat("API logger module loaded. Use fetch_with_logging() for paginated calls.\n")
cat(sprintf("Log file: %s\n", log_file))
