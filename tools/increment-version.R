library(gh)
library(fuj)

desc <- 
  gh("GET https://api.github.com/repos/jmbarbone/actions/contents/DESCRIPTION") |>
  subset2("download_url") |> 
  url() |> 
  read.dcf(keep.white = "Authors@R") |> 
  as.data.frame()

version <- 
  desc |> 
  subset2("Version") |>
  as.package_version() |>
  unclass() |>
  subset2(1L)

version <- unclass(package_version(desc[["Version"]]))[[1L]]
# presuming it's only dev versions
version[4L] <- version[4L] + 1L
desc[["Version"]] <- as.numeric_version(list(version))
write.dcf(desc, "DESCRIPTION", keep.white = "Authors@R")
