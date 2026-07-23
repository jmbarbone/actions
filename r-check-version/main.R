#!/usr/bin/env Rscript
library(scribe)
library(gh)
library(fuj)

catln <- function(...) cat(..., "\n", sep = "")

ca <- command_args(scan(text = "--ignore-dev-version true", what = character()))
ca$add_argument("--directory", default = ".")
ca$add_argument("--ignore-dev-version", default = FALSE)
ca$add_argument("--repository")
args <- ca$parse()

res <- NULL

setwd(args$directory)

catln("::group::Checking for required files")

if (!file.exists("NEWS.md")) {
  catln("\u274C NEWS.md is missing")
  res <- c(res, "NEWS.md is missing")
} else {
  catln("\u2714 NEWS.md found")
}

if (!file.exists("DESCRIPTION")) {
  catln("\u274C DESCRIPTION is missing")
  res <- c(res, "DESCRIPTION is missing")
} else {
  catln("\u2714 DESCRIPTION found")
}

if (!is.null(res)) {
  catln("\u274C Not all required files found")
  catln("::endgroup::")
  res <- c(res, "Not all required files found")
  # early exit because we'll encounter other errors
  stop(collapse("Found the following issues", res, sep = "\n  >> "))
}

catln("\u2714 All required files found")

catln("::endgroup::")

catln("::group::Checking DESCRIPTION")

old_desc <- 
  gh(sprintf(
    "GET https://api.github.com/repos/%s/contents/%s/DESCRIPTION", 
    args$repository,
    args$directory
  )) |> 
  # could add fail check here
  subset2("download_url") |> 
  url() |> 
  read.dcf() 

old_repo <- old_desc[, "Package"]
old_version <- as.package_version(old_desc[, "Version"])

new_desc <- read.dcf("DESCRIPTION")
new_repo <- new_desc[, "Package"]

if (old_repo != new_repo) {
  catln("\u274C Package name has changed")
  res <- c(res, "Package name has changed")
} else {
  catln("\u2714 Package name has not changed")
}

new_version <- as.package_version(new_desc[, "Version"])

if (new_version <= old_version) {
  catln("\u274C Version is not incremented")
  res <- c(res, "Version is not incremented")
} else {
  catln("\u2714 Version is incremented")
}

catln("::endgroup::")

catln("::group::Checking NEWS.md")

news_contents <- readLines("NEWS.md")

ignore_news <- 
  args$ignore_dev_version || 
  any(grepl("(development version)", news_contents, fixed = TRUE))

pattern <- paste("#", new_repo, format(new_version))

if (ignore_news) {
  catln("\u2714 NEWS.md is ignored")
} else if (any(grepl(pattern, news_contents, fixed = TRUE))) {
  catln("\u2714 NEWS.md contains new version")
} else {
  catln("\u274C NEWS.md does not contain new version")
  res <- c(res, "NEWS.md does not contain new version")
}

catln("::endgroup::")

if (length(res) > 0L) {
  stop(collapse("Found the following issues", res, sep = "\n  >> "))
}