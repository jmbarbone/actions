library(gh)
library(yaml)
library(fuj)
library(scribe)

ca <- command_args()
ca$add_argument("--repository")
ca$add_argument("--pull-request-number")
args <- ca$parse()

catln <- function(...) cat(..., "\n", sep = "")
catln("::group::Getting files")
get_pull <- gh(sprintf("GET https://api.github.com/repos/%s/pulls/%s/files", args$repository, args$pull_request_number))

files <- vapply(get_pull, subset2, NA_character_, "filename")
# files <- vap_chr(files, "filename")
files <- files[tolower(tools::file_ext(files)) %in% c("yaml", "yml")]
catln("::endgroup::")

if (length(files) == 0L) {
  catln("\u2714 No yaml files found")
  quit(0)
}

catln("::group::Checking yaml files")
check_yaml <- function(x) {
  tryCatch(
    {
      read_yaml(x, error.label = x)
      NA_character_
    }, 
    error = function(e) conditionMessage(e)
  )
}

checks <- vapply(files, check_yaml, NA_character_, USE.NAMES = FALSE)
# res <- vap_chr(files, check_yaml)
bad <- !is.na(checks)
res <- checks[!bad]

catln("::endgroup::")

for (i in which(bad)) {
  catln(sprintf("::group::%s \u274C", files[i]))
  catln(checks[i])
  catln("::endgroup::")
}

if (any(bad)) {
  catln("\u274C Issues found")
  quit(1)
}

catln("\u2714 Success")
quit(0)
