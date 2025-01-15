
# fbwR

<!-- badges: start -->
<!-- badges: end -->

This is an R package containing the Fish Benefits Workbook - a forebay-to-tailrace model of fish passing downstream of large dams. 
The model was originally created as an Excel Workbook by the United States' Army Corps of Engineers in 2014, and was subsequently recreated as an R package in 2022.

The package includes functions which, given information about dam hydrology, pool elevation, outflow, and fish behavioural responses to hydrological conditions at the dam, 
calculates dam passage efficiency and survival.

## Installation

### Install from a public repository

If the repository is made public, you can install the development version of AHA from GitHub with:

``` r
# install.packages("devtools")
devtools::install_github("mairindeith/fbwR", build_vignettes = TRUE)
```


### Install from a private repository

As of January 2025, this repository is private.
If you want to install the package from a private repository, you will have to establish your GitHub credentials inside of an R session before installation: 

``` r
#set config
usethis::use_git_config(user.name = "YourName", user.email = "your@mail.com")

#Go to github page to generate token
usethis::create_github_token() 

#paste your PAT into pop-up that follows...
credentials::set_github_pat()

#now remotes::install_github() will work
remotes::install_github("mairindeith/fbwR", build_vignettes = TRUE)
```

## Vignette

This package comes with two vignettes. One is a quick-start guide explaining how to use the fbwR package, the other explains data requirements for running the model.

You can access the vignettes using the following R command after the library has been installed: 
``` r
# To see the quickstart vignette:
vignette(package="fbwR", topic = "fbwR-quick-start")
# To see the data requirements vignette:
vignette(package="fbwR", topic = "fbwR-data-needs")
```

## fbwR Shiny app

Once the library is installed, you can also launch a Shiny app front-end to the model. 
The app facilitates uploading and visualize both hydrological and biological variables required by the FBW model, and  input and visualize biological parameter values, and runs the dam passage simulation to generate estimates of fish passage efficiency and survival rates.
Once the fbwR package is installed, you can launch a locally hosted version of the Shiny app like so: 
``` r
fbwR::runApp()
```
