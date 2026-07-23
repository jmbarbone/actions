library(scribe)
library(gh)
library(fuj)

ca <- command_args(scan(text = "--ignore-dev-version true", what = character()))
ca$add_argument("--repository")
ca$add_argument("--pull-request-number")
ca$add_argument("--ignore-dev-version", default = FALSE)
args <- ca$parse()

res <- NULL

cat(
  "gh:                 ", format(packageVersion("gh")), "\n",
  "fuj:                ", format(packageVersion("fuj")), "\n",
  "ignore-dev-version: ", args$ignore_dev_version, "\n",
  sep = ""
)

cat("::group::Getting files\n")
get_pull <- gh(sprintf("GET https://api.github.com/repos/%s/pulls/%s/files", args$repository, args$pull_request_number))

if (!length(get_pull)) {
  cat("No files found\n")
  cat("::endgroup::\n")
  quit("no")
}

files <- vapply(get_pull, subset2, NA_character_, "filename")
cat("::endgroup::\n")

cat("::group::Checking for required files\n")

if ("NEWS.md" %out% files) {
  cat("\u274C NEWS.md is missing\n")
  res <- c(res, "NEWS.md is missing")
} else {
  cat("\u2714 NEWS.md found\n")
}

if ("DESCRIPTION" %out% files) {
  cat("\u274C DESCRIPTION is missing\n")
  res <- c(res, "DESCRIPTION is missing")
} else {
  cat("\u2714 DESCRIPTION found\n")
}

if (!is.null(res)) {
  cat("\u274C Not all required files found\n")
  cat("::endgroup::\n")
  res <- c(res, "Not all required files found")
  # early exit because we'll encounter other errors
  stop(collapse("Found the following issues", res, sep = "\n  >> "))
}

cat("\u2714 All required files found\n")

cat("::endgroup::\n")

cat("::group::Checking DESCRIPTION\n")

old_desc <- 
  gh(paste("GET", "https://api.github.com/repos", args$repository, "contents/DESCRIPTION", sep = "/")) |> 
  # could add fail check here
  subset2("download_url") |> 
  url() |> 
  read.dcf() 

old_repo <- old_desc[, "Package"]
old_version <- as.package_version(old_desc[, "Version"])

new_desc <- 
  gh(paste("GET", get_pull[[which(files == "DESCRIPTION")]]$contents_url)) |> 
  subset2("download_url") |>
  url() |>
  read.dcf() 

new_repo <- new_desc[, "Package"]

if (old_repo != new_repo) {
  cat("\u274C Package name has changed\n")
  res <- c(res, "Package name has changed")
} else {
  cat("\u2714 Package name has not changed\n")
}

new_version <- as.package_version(new_desc[, "Version"])

if (new_version <= old_version) {
  cat("\u274C Version is not incremented\n")
  res <- c(res, "Version is not incremented")
} else {
  cat("\u2714 Version is incremented\n")
}

cat("::endgroup::\n")

cat("::group::Checking NEWS.md\n")

news_url <- 
  get_pull[[which(files == "NEWS.md")]] |>
  subset2("contents_url")

news_contents <- 
  gh(paste("GET", news_url)) |>
  # could add fail check here
  subset2("download_url") |>
  url() |> 
  readLines()

ignore_news <- 
  args$ignore_dev_version || 
  any(grepl("(development version)", news_contents, fixed = TRUE))

pattern <- paste("#", new_repo, format(new_version))

if (ignore_news) {
  cat("\u2714 NEWS.md is ignored\n")
} else if (any(grepl(pattern, news_contents, fixed = TRUE))) {
  cat("\u2714 NEWS.md contains new version\n")
} else {
  cat("\u274C NEWS.md does not contain new version\n")
  res <- c(res, "NEWS.md does not contain new version")
}

cat("::endgroup::\n")

if (length(res)) {
  stop(collapse("Found the following issues", res, sep = "\n  >> "))
}